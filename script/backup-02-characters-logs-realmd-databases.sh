#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly CONTAINER_NAME="vmangos-database"
readonly CONTAINER_SCRIPT="/home/default/scripts/02-characters-logs-realmd-databases-backup.sh"

readonly BACKUP_DIR="$PROJECT_ROOT/backup"
readonly SQL_FILE="$BACKUP_DIR/full_backup.sql"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

send_discord_message() {
    local message="$1"

    if [ -z "${DISCORD_WEBHOOK:-}" ]; then
        log_message "WARNING" "Discord webhook not configured, skipping notification"
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

main() {
    local timestamp
    local archive_file
    local backup_size

    log_message "INFO" "Script started"

    # Load optional Discord configuration
    if [ -f "$PROJECT_ROOT/.env-script" ]; then
        source "$PROJECT_ROOT/.env-script"
    else
        log_message "WARNING" "Environment file not found: $PROJECT_ROOT/.env-script"
    fi

    if [ ! -d "$BACKUP_DIR" ]; then
        log_message "ERROR" "Backup directory not found: $BACKUP_DIR"
        return 1
    fi

    log_message "INFO" "Creating database backup"

    if ! sudo docker exec "$CONTAINER_NAME" "$CONTAINER_SCRIPT"; then
        log_message "ERROR" "Database backup failed"
        send_discord_message "Daily SQL dump backup failed during database dump"
        return 1
    fi

    log_message "SUCCESS" "Database backup created successfully"

    if [ ! -f "$SQL_FILE" ]; then
        log_message "ERROR" "SQL dump not found: $SQL_FILE"
        send_discord_message "Daily SQL dump backup failed: SQL dump was not created"
        return 1
    fi

    timestamp=$(date "+%Y%m%d_%H%M%S")
    archive_file="$BACKUP_DIR/full_backup_${timestamp}.7z"

    log_message "INFO" "Compressing database backup"

    if ! 7z a "$archive_file" "$SQL_FILE"; then
        log_message "ERROR" "Failed to compress database backup"
        send_discord_message "Daily SQL dump backup failed during compression"
        return 1
    fi

    log_message "SUCCESS" "Database backup compressed successfully"

    backup_size=$(du -h "$archive_file" | cut -f1)
    log_message "INFO" "Backup file size: $backup_size"

    log_message "INFO" "Removing uncompressed database dump"
    rm -f "$SQL_FILE"

    send_discord_message \
        "Daily SQL dump backup completed successfully. Size: $backup_size"

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
