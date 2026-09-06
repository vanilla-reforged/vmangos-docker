#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly ENV_SCRIPT_FILE="$PROJECT_ROOT/.env-script"

readonly MANGOS_LOG_DIR="$PROJECT_ROOT/vol/logs/mangos"
readonly REALMD_LOG_DIR="$PROJECT_ROOT/vol/logs/realmd"
readonly HONOR_LOG="$MANGOS_LOG_DIR/honor/honor.log"

readonly RETENTION_DAYS=21

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    printf '[%s] [%s] [%s] %s\n' \
        "$timestamp" \
        "$SCRIPT_NAME" \
        "$level" \
        "$message"
}

send_discord_message() {
    local message="$1"

    if [ -z "${DISCORD_WEBHOOK:-}" ]; then
        log_message "WARNING" \
            "Discord webhook not configured, skipping notification"
        return
    fi

    log_message "INFO" "Sending Discord notification"

    if curl -fsS \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$(jq -nc --arg content "$message" '{content: $content}')" \
        "$DISCORD_WEBHOOK" > /dev/null; then

        log_message "SUCCESS" "Discord notification sent successfully"
    else
        log_message "ERROR" "Failed to send Discord notification"
    fi
}

remove_old_entries() {
    local log_file="$1"
    local cutoff
    local temp_file
    local filename
    local lines_before
    local lines_after
    local lines_removed

    filename="${log_file##*/}"

    if [ ! -f "$log_file" ]; then
        log_message "WARNING" "Log file not found: $log_file"
        return
    fi

    cutoff=$(date -d "$RETENTION_DAYS days ago" +%s)
    temp_file=$(mktemp "${log_file}.tmp.XXXXXX")

    lines_before=$(wc -l < "$log_file")

    if ! awk -v cutoff="$cutoff" '
        {
            timestamp = substr($0, 1, 19)

            if (timestamp !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/) {
                print
                next
            }

            gsub(/[-: ]/, " ", timestamp)
            epoch = mktime(timestamp)

            if (epoch >= cutoff) {
                print
            }
        }
    ' "$log_file" > "$temp_file"; then

        rm -f "$temp_file"

        log_message "ERROR" "Failed to clean log file: $filename"
        return 1
    fi

    lines_after=$(wc -l < "$temp_file")
    lines_removed=$((lines_before - lines_after))

    # Rewrite the existing file instead of replacing it.
    # This preserves ownership, permissions, and inode.
    if ! cat "$temp_file" > "$log_file"; then
        rm -f "$temp_file"

        log_message "ERROR" "Failed to update log file: $filename"
        return 1
    fi

    rm -f "$temp_file"

    log_message "SUCCESS" \
        "Removed $lines_removed old entries from $filename"
}

cleanup_directory() {
    local log_directory="$1"
    local log_file

    if [ ! -d "$log_directory" ]; then
        log_message "WARNING" \
            "Log directory not found: $log_directory"
        return
    fi

    shopt -s nullglob

    for log_file in "$log_directory"/*; do
        [ -f "$log_file" ] || continue

        remove_old_entries "$log_file"
    done

    shopt -u nullglob
}

main() {
    log_message "INFO" "Script started"

    # Load optional Discord configuration
    if [ -f "$ENV_SCRIPT_FILE" ]; then
        source "$ENV_SCRIPT_FILE"
    else
        log_message "WARNING" \
            "Environment file not found: $ENV_SCRIPT_FILE"
    fi

    log_message "INFO" \
        "Removing log entries older than $RETENTION_DAYS days"

    log_message "INFO" "Cleaning mangos logs"
    cleanup_directory "$MANGOS_LOG_DIR"

    if [ -f "$HONOR_LOG" ]; then
        log_message "INFO" "Cleaning honor log"
        remove_old_entries "$HONOR_LOG"
    else
        log_message "WARNING" \
            "Honor log not found: $HONOR_LOG"
    fi

    log_message "INFO" "Cleaning realmd logs"
    cleanup_directory "$REALMD_LOG_DIR"

    send_discord_message \
        "Log cleanup completed. Entries older than $RETENTION_DAYS days were removed from mangos, honor, and realmd logs."

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
