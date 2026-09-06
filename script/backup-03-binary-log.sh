#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly CONTAINER_NAME="vmangos-database"
readonly CONTAINER_SCRIPT="/home/default/scripts/03-binary-log-backup.sh"
readonly BACKUP_DIR="$PROJECT_ROOT/backup"

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

compress_binlogs() {
    local binlog
    local filename
    local archive

    shopt -s nullglob

    for binlog in "$BACKUP_DIR"/mysql-bin.[0-9][0-9][0-9][0-9][0-9][0-9]; do
        filename="${binlog##*/}"
        archive="$BACKUP_DIR/${filename}.7z"

        if [ -f "$archive" ]; then
            log_message "INFO" "Archive already exists: ${filename}.7z"
            rm -f "$binlog"
            continue
        fi

        log_message "INFO" "Compressing $filename"

        if ! 7z a -bd -y "$archive" "$binlog" > /dev/null; then
            log_message "ERROR" "Failed to compress $filename"
            return 1
        fi

        if [ ! -s "$archive" ]; then
            log_message "ERROR" "Archive is missing or empty: ${filename}.7z"
            rm -f "$archive"
            return 1
        fi

        rm -f "$binlog"

        log_message "SUCCESS" "Compressed and removed raw binlog: $filename"
    done

    shopt -u nullglob
}

main() {
    log_message "INFO" "Script started"

    if [ ! -d "$BACKUP_DIR" ]; then
        log_message "ERROR" "Backup directory not found: $BACKUP_DIR"
        return 1
    fi

    log_message "INFO" "Copying binary logs from database container"

    if ! sudo docker exec "$CONTAINER_NAME" "$CONTAINER_SCRIPT"; then
        log_message "ERROR" "Failed to copy binary logs from database container"
        return 1
    fi

    log_message "SUCCESS" "Binary logs copied successfully"

    # Remove accidental index files from previous backup runs
    rm -f "$BACKUP_DIR"/mysql-bin.[0-9][0-9][0-9][0-9][0-9][0-9].idx

    log_message "INFO" "Compressing binary logs"

    if ! compress_binlogs; then
        return 1
    fi

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
