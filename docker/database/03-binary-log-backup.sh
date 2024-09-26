#!/bin/bash

# Configuration
CONTAINER_BACKUP_DIR="/vol/backup"  # Backup directory inside the Docker container

# Function to copy binary logs to /vol/backup
copy_binary_logs() {
    echo "Copying binary logs to $CONTAINER_BACKUP_DIR..."

    # Copy binary logs to the mounted backup directory
    cp /var/lib/mysql/mysql-bin.* "$CONTAINER_BACKUP_DIR/"

    if [[ $? -eq 0 ]]; then
        echo "Binary logs copied successfully to $CONTAINER_BACKUP_DIR."
    else
        echo "Failed to copy binary logs!"
        exit 1
    fi
}

# Execute the copy
copy_binary_logs
