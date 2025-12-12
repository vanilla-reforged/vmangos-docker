#!/bin/bash

# Logger function
log_message() {
    local level="$1"
    local message="$2"
    local script_name=$(basename "$0")
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$script_name] [$level] $message"
}

cd "$(dirname "$0")"
log_message "INFO" "Script started"

# Load environment
source ./../../.env-script

# Configuration
DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK"
BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"
DISCORD_LOG_FILE="/tmp/discord_cumulative_log.txt"

log_message "INFO" "Using backup directory: $BACKUP_DIR"

# Run binlog backup inside container
log_message "INFO" "Executing binlog backup inside container"
if ! sudo docker exec vmangos-database /home/default/scripts/03-binary-log-backup.sh; then
    log_message "ERROR" "Container binlog backup failed"
    exit 1
fi

log_message "SUCCESS" "Container binlog backup completed"

# Compress ONLY numeric binlogs
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE="$BACKUP_DIR/binary_logs_$TIMESTAMP.7z"

log_message "INFO" "Compressing incremental binlogs"
if 7z a "$ARCHIVE" "$BACKUP_DIR"/mysql-bin.[0-9][0-9][0-9][0-9][0-9][0-9]; then
    BACKUP_SIZE=$(du -h "$ARCHIVE" | cut -f1)
    log_message "SUCCESS" "Binlog archive created ($BACKUP_SIZE)"
else
    log_message "ERROR" "Binlog compression failed"
    exit 1
fi

# Cleanup uncompressed binlogs
log_message "INFO" "Cleaning up uncompressed binlogs"
rm -f "$BACKUP_DIR"/mysql-bin.[0-9][0-9][0-9][0-9][0-9][0-9]

log_message "SUCCESS" "Cleanup complete"
log_message "INFO" "Script finished successfully"
