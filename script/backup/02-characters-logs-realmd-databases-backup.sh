#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Configuration
DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK"  # Discord webhook URL from .env-script
BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"  # Backup directory on the host system

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK_URL"
}

# Step 1: Run the backup script inside the container
echo "Executing database backup script inside the container..."
sudo docker exec vmangos-database /home/default/scripts/02-characters-logs-realmd-databases-backup.sh

if [[ $? -eq 0 ]]; then
    echo "Database backup script executed successfully."

    # Step 2: Compress the SQL dump
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    echo "Compressing the SQL dump..."
    7z a "$BACKUP_DIR/full_backup_$TIMESTAMP.7z" "$BACKUP_DIR/full_backup.sql"

    if [[ $? -eq 0 ]]; then
        echo "SQL dump compressed successfully."

        # Step 3: Remove the uncompressed SQL dump
        rm -f "$BACKUP_DIR/full_backup.sql"

        # Step 4: Send a success message to Discord
        send_discord_message "Daily SQL dump backup completed successfully."
    else
        echo "Failed to compress SQL dump."
        send_discord_message "Daily SQL dump backup failed during compression."
        exit 1
    fi
else
    echo "Failed to execute backup script inside container."
    send_discord_message "Daily SQL dump backup failed during database dump."
    exit 1
fi
