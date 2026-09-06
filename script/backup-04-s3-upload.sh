#!/bin/bash

# Logger function for standardized logging
log_message() {
    local level="$1"
    local message="$2"
    local script_name=$(basename "$0")
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$script_name] [$level] $message"
}

# Change to the directory where the script is located
cd "$(dirname "$0")"
log_message "INFO" "Script started"

# Load environment variables from .env-script
log_message "INFO" "Loading environment variables"
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Configuration
S3_BUCKET="s3://your-s3-bucket-name"  # S3 bucket name
HOST_BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"  # Local backup directory on the host using $DOCKER_DIRECTORY
log_message "INFO" "Using S3 bucket: $S3_BUCKET"
log_message "INFO" "Using backup directory: $HOST_BACKUP_DIR"

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    log_message "INFO" "Sending Discord message: $message"
    if curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK"; then
        log_message "SUCCESS" "Discord message sent successfully"
    else
        log_message "ERROR" "Failed to send Discord message"
    fi
}

# Function to upload the backup file to S3
upload_to_s3() {
    local BACKUP_FILE=$1
    log_message "INFO" "Uploading $BACKUP_FILE to S3"

    if aws s3 cp "$HOST_BACKUP_DIR/$BACKUP_FILE" "$S3_BUCKET"; then
        FILESIZE=$(du -h "$HOST_BACKUP_DIR/$BACKUP_FILE" | cut -f1)
        log_message "SUCCESS" "$BACKUP_FILE (size: $FILESIZE) uploaded to S3 successfully"
        send_discord_message "Backup $BACKUP_FILE (size: $FILESIZE) uploaded to S3 successfully."
    else
        log_message "ERROR" "Failed to upload $BACKUP_FILE to S3"
        send_discord_message "Failed to upload $BACKUP_FILE to S3."
        exit 1
    fi
}

# List all backup files and upload each
BACKUP_COUNT=0
log_message "INFO" "Scanning for backup files in $HOST_BACKUP_DIR"
for BACKUP_FILE in $(ls $HOST_BACKUP_DIR | grep ".7z"); do
    BACKUP_COUNT=$((BACKUP_COUNT + 1))
    upload_to_s3 "$BACKUP_FILE"
done

log_message "INFO" "Uploaded $BACKUP_COUNT backup files to S3"
log_message "SUCCESS" "Script completed successfully"
exit 0
