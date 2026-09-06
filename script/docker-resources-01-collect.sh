#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly LOG_DIR="$PROJECT_ROOT/vol/docker-resources"
readonly DB_LOG="$LOG_DIR/db_usage.log"
readonly MANGOS_LOG="$LOG_DIR/mangos_usage.log"
readonly REALMD_LOG="$LOG_DIR/realmd_usage.log"
readonly ERROR_LOG="$LOG_DIR/error.log"

readonly RETENTION_DAYS=8

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

log_error() {
    local message="$1"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    printf '[%s] %s\n' \
        "$timestamp" \
        "$message" >> "$ERROR_LOG"
}

convert_memory_to_mib() {
    local memory="$1"
    local value

    memory="${memory// /}"

    case "$memory" in
        *GiB)
            value="${memory%GiB}"
            awk -v value="$value" 'BEGIN { printf "%.2f", value * 1024 }'
            ;;
        *MiB)
            value="${memory%MiB}"
            printf '%s\n' "$value"
            ;;
        *KiB)
            value="${memory%KiB}"
            awk -v value="$value" 'BEGIN { printf "%.2f", value / 1024 }'
            ;;
        *)
            return 1
            ;;
    esac
}

clean_old_entries() {
    local log_file="$1"
    local threshold
    local temp_file
    local before_count
    local after_count
    local removed_count

    if [ ! -f "$log_file" ]; then
        return
    fi

    threshold=$(date -d "$RETENTION_DAYS days ago" +%s)
    temp_file=$(mktemp "${log_file}.tmp.XXXXXX")

    before_count=$(wc -l < "$log_file")

    if ! awk -F',' -v threshold="$threshold" \
        '$2 >= threshold' "$log_file" > "$temp_file"; then

        rm -f "$temp_file"

        log_message "ERROR" "Failed to clean old entries from ${log_file##*/}"
        log_error "Failed to clean old entries from $log_file"

        return 1
    fi

    after_count=$(wc -l < "$temp_file")
    removed_count=$((before_count - after_count))

    # Rewrite the existing file instead of replacing it.
    # This preserves its ownership, permissions, and inode.
    if ! cat "$temp_file" > "$log_file"; then
        rm -f "$temp_file"

        log_message "ERROR" "Failed to update ${log_file##*/}"
        log_error "Failed to update $log_file"

        return 1
    fi

    rm -f "$temp_file"

    if (( removed_count > 0 )); then
        log_message "INFO" \
            "Removed $removed_count old entries from ${log_file##*/}"
    fi
}

collect_usage() {
    local container_name="$1"
    local log_file="$2"
    local memory_raw
    local memory_usage
    local timestamp
    local human_timestamp

    if ! sudo docker container inspect \
        --format '{{.State.Running}}' \
        "$container_name" 2>/dev/null | grep -qx 'true'; then

        log_message "WARNING" "Container is not running: $container_name"
        log_error "Container is not running: $container_name"

        return
    fi

    log_message "INFO" "Collecting memory usage for $container_name"

    memory_raw=$(
        sudo docker stats \
            --no-stream \
            --format '{{.MemUsage}}' \
            "$container_name" 2>/dev/null |
        awk -F'/' '{print $1}'
    )

    if [ -z "$memory_raw" ]; then
        log_message "WARNING" "Unable to collect memory usage for $container_name"
        log_error "Unable to collect memory usage for $container_name"

        return
    fi

    if ! memory_usage=$(convert_memory_to_mib "$memory_raw"); then
        log_message "WARNING" \
            "Unable to parse memory usage for $container_name: $memory_raw"
        log_error \
            "Unable to parse memory usage for $container_name: $memory_raw"

        return
    fi

    timestamp=$(date +%s)
    human_timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    printf '%s,%s,%s\n' \
        "$human_timestamp" \
        "$timestamp" \
        "$memory_usage" >> "$log_file"

    log_message "INFO" \
        "Recorded $container_name memory usage: $memory_usage MiB"

    clean_old_entries "$log_file"
}

main() {
    log_message "INFO" "Script started"

    if ! mkdir -p "$LOG_DIR"; then
        log_message "ERROR" "Failed to create log directory: $LOG_DIR"
        return 1
    fi

    log_message "INFO" "Using log directory: $LOG_DIR"

    collect_usage "vmangos-database" "$DB_LOG"
    collect_usage "vmangos-mangos" "$MANGOS_LOG"
    collect_usage "vmangos-realmd" "$REALMD_LOG"

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
