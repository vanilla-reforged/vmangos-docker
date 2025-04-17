#!/bin/bash

# Logger function for standardized logging
log_message() {
    local level="$1"
    local message="$2"
    local script_name=$(basename "$0")
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$script_name] [$level] $message"
}

# Change to the directory where the script is located
cd "$(dirname "$0")"
log_message "INFO" "Script started"

# Load environment variables
log_message "INFO" "Loading environment variables"
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Configuration
DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK"  # Discord webhook URL from .env-script
BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"  # Backup directory on the host system
log_message "INFO" "Using backup directory: $BACKUP_DIR"

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    log_message "INFO" "Sending Discord message: $message"
    if curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK_URL"; then
        log_message "SUCCESS" "Discord message sent successfully"
    else
        log_message "ERROR" "Failed to send Discord message"
    fi
}

# Step 1: Run the backup script inside the container
log_message "INFO" "Executing database backup script inside the container"
if sudo docker exec vmangos-database /home/default/scripts/02-characters-logs-realmd-databases-backup.sh; then
    log_message "SUCCESS" "Database backup script executed successfully"

    # Step 2: Compress the SQL dump
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    log_message "INFO" "Compressing the SQL dump"
    if 7z a "$BACKUP_DIR/full_backup_$TIMESTAMP.7z" "$BACKUP_DIR/full_backup.sql"; then
        log_message "SUCCESS" "SQL dump compressed successfully"
        
        # Get the compressed file size
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/full_backup_$TIMESTAMP.7z" | cut -f1)
        log_message "INFO" "Backup file size: $BACKUP_SIZE"

        # Step 3: Remove the uncompressed SQL dump
        log_message "INFO" "Removing uncompressed SQL dump"
        rm -f "$BACKUP_DIR/full_backup.sql"

        # Step 4: Send a success message to Discord
        send_discord_message "Daily SQL dump backup completed successfully. Size: $BACKUP_SIZE"
    else
        log_message "ERROR" "Failed to compress SQL dump"
        send_discord_message "Daily SQL dump backup failed during compression"
        exit 1
    fi
else
    log_message "ERROR" "Failed to execute backup script inside container"
    send_discord_message "Daily SQL dump backup failed during database dump"
    exit 1
fi

log_message "INFO" "Script completed successfully"
