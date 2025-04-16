#!/bin/bash
# Run with nice (CPU priority 19) and ionice (I/O priority class 3)
# This is pure file I/O, so use I/O class 3 (idle) to minimize impact
nice -n 19 ionice -c 3 bash -c '
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
'
