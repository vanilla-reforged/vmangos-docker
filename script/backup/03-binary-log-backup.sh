#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables from .env-script
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Configuration
HOST_BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"  # Backup directory on the host using $DOCKER_DIRECTORY

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK"
}

# Step 1: Run the internal backup script inside the container
echo "Executing binary log backup script inside the container..."
docker exec vmangos-database /03-binary-log-backup.sh

if [[ $? -eq 0 ]]; then
    echo "Binary log backup script executed successfully inside the container."

    # Step 2: Compress the binary logs
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    echo "Compressing the binary logs..."
    7z a "$HOST_BACKUP_DIR/binary_logs_$TIMESTAMP.7z" "$HOST_BACKUP_DIR/mysql-bin.*"

    if [[ $? -eq 0 ]]; then
        echo "Binary logs compressed successfully."

        # Step 3: Clean up uncompressed binary logs
        echo "Removing uncompressed binary logs..."
        rm -f "$HOST_BACKUP_DIR/mysql-bin.*"

        if [[ $? -eq 0 ]]; then
            echo "Uncompressed binary logs cleaned up successfully."

            # Step 4: Send a success message to Discord
            send_discord_message "Incremental binary logs backup completed successfully."
        else
            echo "Failed to clean up uncompressed binary logs."
            send_discord_message "Incremental binary logs backup failed during cleanup."
            exit 1
        fi
    else
        echo "Failed to compress binary logs."
        send_discord_message "Incremental binary logs backup failed during compression."
        exit 1
    fi
else
    echo "Failed to execute binary log backup script inside the container."
    send_discord_message "Incremental binary logs backup failed during the log copy."
    exit 1
fi
