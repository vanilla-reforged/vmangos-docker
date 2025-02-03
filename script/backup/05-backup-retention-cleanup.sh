#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables from .env-script
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Configuration
HOST_BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"  # Local backup directory on the host using $DOCKER_DIRECTORY
CONTAINER_BACKUP_DIR="/vol/backup"  # Backup directory inside the Docker container
BACKUP_RETENTION_DAYS=8  # Retain backups for 8 days

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK"
}

# Function to clean up old backups and binary logs
clean_up_old_backups() {
    local deleted_count=$(find "$HOST_BACKUP_DIR" -type f -name "*.7z" -mtime +$BACKUP_RETENTION_DAYS -print | wc -l)
    find "$HOST_BACKUP_DIR" -type f -name "*.7z" -mtime +$BACKUP_RETENTION_DAYS -exec rm -f {} \;
    
    echo "Deleted $deleted_count backup files older than $BACKUP_RETENTION_DAYS days"
    send_discord_message "Deleted $deleted_count backup files"
}

# Execute cleanup
clean_up_old_backups

exit 0
