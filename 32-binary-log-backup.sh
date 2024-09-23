#!/bin/bash

# Load environment variables from .env-script
source "$(dirname "$0")/.env-script"

# Configuration
CONTAINER_BACKUP_DIR="/vol/backup"  # Backup directory inside the Docker container
CONTAINER_NAME="vmangos-database"  # Docker container name
BINARY_LOGS_RETENTION_DAYS=7  # Retain binary logs for 7 days

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK"
}

# Function to create an incremental backup using binary logs
create_incremental_backup() {
    echo "Creating incremental backup using binary logs inside the container..."
    
    # Copy binary logs from container to the backup directory
    docker exec $CONTAINER_NAME bash -c "cp /var/lib/mysql/mysql-bin.* $CONTAINER_BACKUP_DIR/"

    if [[ $? -eq 0 ]]; then
        echo "Binary logs copied successfully."
        
        # Compress the binary logs
        echo "Compressing binary logs..."
        docker exec $CONTAINER_NAME bash -c "7z a $CONTAINER_BACKUP_DIR/binary_logs.7z $CONTAINER_BACKUP_DIR/mysql-bin.*"
        
        if [[ $? -eq 0 ]]; then
            echo "Binary logs compressed successfully."
            send_discord_message "Incremental binary logs backup completed successfully."
        else
            echo "Failed to compress binary logs!"
            send_discord_message "Incremental binary logs backup failed during compression."
            exit 1
        fi
    else
        echo "Failed to copy binary logs!"
        send_discord_message "Incremental binary logs backup failed."
        exit 1
    fi
}

# Execute incremental backup
create_incremental_backup

exit 0
