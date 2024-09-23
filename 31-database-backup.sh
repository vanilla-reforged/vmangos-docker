#!/bin/bash

# Load environment variables
source "$(dirname "$0")/.env"

# Configuration
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/your_webhook_id"  # Replace with your Discord webhook URL
HOST_BACKUP_DIR="./vol/backup"  # Local backup directory on the host
CONTAINER_BACKUP_DIR="/vol/backup"  # Backup directory inside the Docker container
FULL_BACKUP_DIR="$HOST_BACKUP_DIR/full_$(date +%Y%m%d%H%M%S)"  # Directory for full backups on the host
INCREMENTAL_BACKUP_DIR="$HOST_BACKUP_DIR/incremental_$(date +%Y%m%d%H%M%S)"  # Directory for incremental backups on the host
S3_BUCKET="s3://your-s3-bucket-name"  # S3 bucket name
USE_S3=true  # Set to false if you do not want to use S3
DB_USER="mangos"  # Database username
DB_PASS="$MYSQL_ROOT_PASSWORD"  # Database password sourced from .env
CONTAINER_NAME="vmangos-database"  # Docker container name

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK_URL"
}

# Function to create a full backup (daily)
create_full_backup() {
    clean_container_backup_directory
    echo "Creating full backup inside the container..."
    
    # Backup specific databases: characters, logs, realmd
    docker exec $CONTAINER_NAME bash -c "mariabackup --backup --target-dir=$CONTAINER_BACKUP_DIR --user=$DB_USER --password=$DB_PASS --databases='characters logs realmd'"
    
    if [[ $? -eq 0 ]]; then
        echo "Full backup created successfully inside the container."
        mkdir -p "$FULL_BACKUP_DIR"
        
        # Ensure backup files exist before proceeding
        if [ "$(ls -A $CONTAINER_BACKUP_DIR)" ]; then
            echo "Copying backup files from container to host..."
            cp -r $HOST_BACKUP_DIR/* "$FULL_BACKUP_DIR"

            echo "Compressing full backup directory..."
            7z a "$FULL_BACKUP_DIR.7z" "$FULL_BACKUP_DIR"
            
            if [[ $? -eq 0 ]]; then
                echo "Backup directory compressed successfully."
                # Optionally remove uncompressed backups after compressing
                rm -rf "$FULL_BACKUP_DIR"
                if [[ "$USE_S3" == true ]]; then
                    copy_to_s3 "$FULL_BACKUP_DIR.7z" || return 1
                fi
                send_discord_message "Daily backup completed successfully."
            else
                echo "Failed to compress backup directory!"
                send_discord_message "Daily backup failed during compression."
                exit 1
            fi
        else
            echo "No backup files found in $CONTAINER_BACKUP_DIR!"
            send_discord_message "Daily backup failed: No backup files found in the container."
            exit 1
        fi
    else
        echo "Failed to create full backup!"
        send_discord_message "Daily backup failed."
        exit 1
    fi
}

# Copy to S3
copy_to_s3() {
    local BACKUP_PATH=$1
    echo "Uploading $BACKUP_PATH to S3..."
    aws s3 cp "$BACKUP_PATH" "$S3_BUCKET"
    
    if [[ $? -eq 0 ]]; then
        echo "$BACKUP_PATH uploaded to S3 successfully."
        return 0
    else
        echo "Failed to upload $BACKUP_PATH to S3!"
        send_discord_message "Failed to upload backup to S3."
        return 1
    fi
}

# Main execution logic (force full backup for testing)
create_full_backup
