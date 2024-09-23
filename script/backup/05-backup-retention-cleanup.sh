#!/bin/bash

# Load environment variables from .env-script
source "$(dirname "$0")/.env-script"

# Configuration
HOST_BACKUP_DIR="./vol/backup"  # Local backup directory on the host
CONTAINER_BACKUP_DIR="/vol/backup"  # Backup directory inside the Docker container
BINARY_LOGS_RETENTION_DAYS=7  # Retain binary logs for 7 days
BACKUP_RETENTION_DAYS=8  # Retain backups for 8 days

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK"
}

# Function to clean up old backups and binary logs
clean_up_old_backups() {
    echo "Cleaning up local backups older than $BACKUP_RETENTION_DAYS days..."
    find "$HOST_BACKUP_DIR" -type f -name "*.7z" -mtime +$BACKUP_RETENTION_DAYS -exec rm -f {} \;
    
    echo "Cleaning up old binary logs..."
    docker exec "$CONTAINER_NAME" bash -c "find $CONTAINER_BACKUP_DIR -type f -name 'mysql-bin.*' -mtime +$BINARY_LOGS_RETENTION_DAYS -exec rm -f {} \;"
    
    echo "Old backups and binary logs cleaned up successfully."
    send_discord_message "Old backups and binary logs cleaned up."
}

# Execute cleanup
clean_up_old_backups

exit 0
