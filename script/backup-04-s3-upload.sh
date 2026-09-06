#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly S3_BUCKET="s3://your-s3-bucket-name"
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

upload_to_s3() {
    local backup_file="$1"
    local filename
    local file_size

    filename="${backup_file##*/}"

    log_message "INFO" "Uploading $filename to S3"

    if ! aws s3 cp "$backup_file" "$S3_BUCKET/"; then
        log_message "ERROR" "Failed to upload $filename to S3"
        send_discord_message "Failed to upload $filename to S3."
        return 1
    fi

    file_size=$(du -h "$backup_file" | cut -f1)

    log_message "SUCCESS" "$filename (size: $file_size) uploaded to S3 successfully"

    send_discord_message \
        "Backup $filename (size: $file_size) uploaded to S3 successfully."
}

main() {
    local backup_file
    local backup_count=0

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

    log_message "INFO" "Using S3 bucket: $S3_BUCKET"
    log_message "INFO" "Scanning for backup files in $BACKUP_DIR"

    shopt -s nullglob

    for backup_file in "$BACKUP_DIR"/*.7z; do
        if ! upload_to_s3 "$backup_file"; then
            shopt -u nullglob
            return 1
        fi

        ((backup_count += 1))
    done

    shopt -u nullglob

    if (( backup_count == 0 )); then
        log_message "INFO" "No backup files found for upload"
    else
        log_message "SUCCESS" "Uploaded $backup_count backup file(s) to S3"
    fi

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
