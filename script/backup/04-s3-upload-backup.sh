#!/bin/bash

# Load environment variables from .env-script
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Configuration
S3_BUCKET="s3://your-s3-bucket-name"  # S3 bucket name
HOST_BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"  # Local backup directory on the host using $DOCKER_DIRECTORY

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK"
}

# Function to upload the backup file to S3
upload_to_s3() {
    local BACKUP_FILE=$1
    echo "Uploading $BACKUP_FILE to S3..."

    aws s3 cp "$HOST_BACKUP_DIR/$BACKUP_FILE" "$S3_BUCKET"
    
    if [[ $? -eq 0 ]]; then
        echo "$BACKUP_FILE uploaded to S3 successfully."
        send_discord_message "Backup $BACKUP_FILE uploaded to S3 successfully."
    else
        echo "Failed to upload $BACKUP_FILE to S3!"
        send_discord_message "Failed to upload $BACKUP_FILE to S3."
        exit 1
    fi
}

# List all backup files and upload each
for BACKUP_FILE in $(ls $HOST_BACKUP_DIR | grep ".7z"); do
    upload_to_s3 "$BACKUP_FILE"
done

exit 0
