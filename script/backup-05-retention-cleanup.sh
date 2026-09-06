#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly BACKUP_DIR="$PROJECT_ROOT/backup"
readonly RETENTION_DAYS=8
readonly RETENTION_MINUTES=$((RETENTION_DAYS * 24 * 60))

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

main() {
    local backup_file
    local file_kb
    local deleted_count=0
    local total_kb=0
    local total_size
    local message

    log_message "INFO" "Script started"

    # Load environment variables
    if [ ! -f "$PROJECT_ROOT/.env-script" ]; then
        log_message "ERROR" "Environment file not found: $PROJECT_ROOT/.env-script"
        return 1
    fi

    source "$PROJECT_ROOT/.env-script"

    # Validate required configuration
    if [ -z "${DISCORD_WEBHOOK:-}" ]; then
        log_message "ERROR" "DISCORD_WEBHOOK is not configured"
        return 1
    fi

    if [ ! -d "$BACKUP_DIR" ]; then
        log_message "ERROR" "Backup directory not found: $BACKUP_DIR"
        return 1
    fi

    log_message "INFO" "Using backup directory: $BACKUP_DIR"
    log_message "INFO" "Retention period: $RETENTION_DAYS days"
    log_message "INFO" "Searching for expired .7z backups"

    while IFS= read -r -d '' backup_file; do
        file_kb=$(du -k "$backup_file" | cut -f1)

        if rm -f "$backup_file"; then
            total_kb=$((total_kb + file_kb))
            deleted_count=$((deleted_count + 1))

            log_message "INFO" \
                "Deleted: ${backup_file##*/} (${file_kb} KB)"
        else
            log_message "ERROR" \
                "Failed to delete: ${backup_file##*/}"
            return 1
        fi
    done < <(
        find "$BACKUP_DIR" \
            -type f \
            -name "*.7z" \
            -mmin "+$RETENTION_MINUTES" \
            -print0
    )

    if (( total_kb >= 1024 )); then
        total_size=$(awk -v kb="$total_kb" \
            'BEGIN { printf "%.2f MB", kb / 1024 }')
    else
        total_size="${total_kb} KB"
    fi

    message="Deleted $deleted_count .7z backup file(s) older than $RETENTION_DAYS days (freed ~$total_size)."

    log_message "SUCCESS" "$message"
    send_discord_message "$message"

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
