#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly CONTAINER_NAME="vmangos-database"
readonly CONTAINER_SCRIPT="/home/default/scripts/01-mangos-database-backup.sh"

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

main() {
    log_message "INFO" "Script started"
    log_message "INFO" "Executing database backup inside container"

    if sudo docker exec "$CONTAINER_NAME" "$CONTAINER_SCRIPT"; then
        log_message "SUCCESS" "Database backup completed successfully"
    else
        log_message "ERROR" "Database backup failed"
        return 1
    fi

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
