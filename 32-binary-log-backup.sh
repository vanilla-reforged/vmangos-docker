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
    echo "Creating incremental backup using binary logs inside the container..."

    # Copy binary logs from container to the backup directory (directly, since mounted)
    docker exec $CONTAINER_NAME bash -c "cp /var/lib/mysql/mysql-bin.* $CONTAINER_BACKUP_DIR/"

    if [[ $? -eq 0 ]]; then
        echo "Binary logs copied successfully to mounted directory ($CONTAINER_BACKUP_DIR)."

        # Compress the binary logs on the host
        echo "Compressing binary logs on the host..."
        7z a "$HOST_BACKUP_DIR/binary_logs_$(date +%Y%m%d%H%M%S).7z" "$HOST_BACKUP_DIR/mysql-bin.*"

        if [[ $? -eq 0 ]]; then
            echo "Binary logs compressed successfully on the host."
            send_discord_message "Incremental binary logs backup completed successfully."

                # Clean up the uncompressed binary logs on the host
                rm "$HOST_BACKUP_DIR/mysql-bin.*"
                if [[ $? -eq 0 ]]; then
                    echo "Uncompressed binary logs cleaned up."
                else
                    echo "Failed to clean up binary logs! Please check file permissions."
                fi

        else
            echo "Failed to compress binary logs on the host!"
            send_discord_message "Incremental binary logs backup failed during compression."
            exit 1
        fi
    else
        echo "Failed to copy binary logs from container!"
        send_discord_message "Incremental binary logs backup failed."
        exit 1
    fi
}

# Execute incremental backup
create_incremental_backup

exit 0
