#!/bin/bash

# Load environment variables from .env-script
source "$(dirname "$0")/.env-script"

# Configuration
CONTAINER_BACKUP_DIR="/vol/backup"  # Backup directory inside the Docker container
HOST_BACKUP_DIR="./vol/backup"  # Backup directory on the host
CONTAINER_NAME="vmangos-database"  # Docker container name

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
    echo "Creating incremental backup using binary logs..."

    # Copy binary logs from container to the host backup directory
    docker cp "$CONTAINER_NAME:/var/lib/mysql/mysql-bin.*" "$HOST_BACKUP_DIR/"

    if [[ $? -eq 0 ]]; then
        echo "Binary logs copied to host backup directory successfully."

        # Compress the binary logs
        echo "Compressing binary logs..."
        7z a "$HOST_BACKUP_DIR/binary_logs_$(date +%Y%m%d%H%M%S).7z" "$HOST_BACKUP_DIR/mysql-bin.*"

        if [[ $? -eq 0 ]]; then
            echo "Binary logs compressed successfully on the host."
            send_discord_message "Incremental binary logs backup completed successfully."

            # Clean up the uncompressed binary logs from the host backup directory
            echo "Cleaning up uncompressed binary logs..."
            find "$HOST_BACKUP_DIR" -type f -name "mysql-bin.*" -exec rm -f {} \;
        else
            echo "Failed to compress binary logs!"
            send_discord_message "Incremental binary logs backup failed during compression."
            exit 1
        fi
    else
        echo "Failed to copy binary logs from container to host!"
        send_discord_message "Incremental binary logs backup failed."
        exit 1
    fi
}

# Execute incremental backup
create_incremental_backup

exit 0
