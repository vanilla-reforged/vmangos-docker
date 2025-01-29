#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Add timestamp to the log file at the start of execution
echo "=== Script started at $(date '+%Y-%m-%d %H:%M:%S') ==="

# Load environment variables from .env-script
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Configuration
HOST_BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"  # Backup directory on the host using $DOCKER_DIRECTORY
DISCORD_LOG_FILE="/tmp/discord_cumulative_log.txt"  # Temporary log file for cumulative messages

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK"
}

# Function to append a message to the cumulative log
append_to_cumulative_log() {
    local message=$1
    echo "[$(date)] $message" >> "$DISCORD_LOG_FILE"
}

# Function to send cumulative messages
send_cumulative_messages() {
    if [[ -f "$DISCORD_LOG_FILE" && -s "$DISCORD_LOG_FILE" ]]; then
        local messages
        messages=$(cat "$DISCORD_LOG_FILE")
        send_discord_message "Cumulative Update:\n$messages"
        > "$DISCORD_LOG_FILE"  # Clear the log file after sending
    fi
}

# Step 1: Run the internal backup script inside the container
echo "Executing binary log backup script inside the container..."
sudo docker exec vmangos-database /home/default/scripts/03-binary-log-backup.sh

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
        eval rm -f "$HOST_BACKUP_DIR/mysql-bin.*"

        if [[ $? -eq 0 ]]; then
            echo "Uncompressed binary logs cleaned up successfully."

            # Append success message to the cumulative log
            append_to_cumulative_log "Incremental binary logs backup completed successfully."
        else
            echo "Failed to clean up uncompressed binary logs."
            append_to_cumulative_log "Incremental binary logs backup failed during cleanup."
            exit 1
        fi
    else
        echo "Failed to compress binary logs."
        append_to_cumulative_log "Incremental binary logs backup failed during compression."
        exit 1
    fi
else
    echo "Failed to execute binary log backup script inside the container."
    append_to_cumulative_log "Incremental binary logs backup failed during the log copy."
    exit 1
fi

# Send cumulative messages if it's 6 AM or 6 PM
CURRENT_HOUR=$(date +%H)
if [[ "$CURRENT_HOUR" == "06" || "$CURRENT_HOUR" == "18" ]]; then
    send_cumulative_messages
fi
