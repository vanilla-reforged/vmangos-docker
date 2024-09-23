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
BINARY_LOGS_RETENTION_DAYS=7  # Retain binary logs for 7 days

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK_URL"
}

# Function to create a full SQL dump (daily)
create_full_backup() {
    echo "Creating full SQL dump inside the container..."
    
    # Dump specific databases: characters, logs, realmd
    docker exec $CONTAINER_NAME bash -c "mysqldump --user=$DB_USER --password=$DB_PASS --databases characters logs realmd > $CONTAINER_BACKUP_DIR/full_backup.sql"
    
    if [[ $? -eq 0 ]]; then
        echo "Full SQL dump created successfully inside the container."
        mkdir -p "$FULL_BACKUP_DIR"
        
        # Compress the SQL dump
        echo "Compressing full SQL dump..."
        docker exec $CONTAINER_NAME bash -c "7z a $CONTAINER_BACKUP_DIR/full_backup.7z $CONTAINER_BACKUP_DIR/full_backup.sql"
        
        if [[ $? -eq 0 ]]; then
            echo "Full SQL dump compressed successfully."
            send_discord_message "Daily SQL dump backup completed successfully."
        else
            echo "Failed to compress full SQL dump!"
            send_discord_message "Daily SQL dump backup failed during compression."
            exit 1
        fi
    else
        echo "Failed to create full SQL dump!"
        send_discord_message "Daily SQL dump backup failed."
        exit 1
    fi
}

# Function to create an incremental backup using binary logs (hourly or minutely)
create_incremental_backup() {
    echo "Creating incremental backup using binary logs inside the container..."
    mkdir -p "$INCREMENTAL_BACKUP_DIR"
    
    # Copy binary logs from container to host
    docker exec $CONTAINER_NAME bash -c "cp /var/lib/mysql/mysql-bin.* $CONTAINER_BACKUP_DIR/"
    
    if [[ $? -eq 0 ]]; then
        echo "Binary logs copied successfully."
        
        # Compress the binary logs
        echo "Compressing binary logs..."
        docker exec $CONTAINER_NAME bash -c "7z a $CONTAINER_BACKUP_DIR/binary_logs.7z $CONTAINER_BACKUP_DIR/mysql-bin.*"
        
        if [[ $? -eq 0 ]]; then
            echo "Binary logs compressed successfully."
            send_discord_message "Hourly binary logs backup completed successfully."
        else
            echo "Failed to compress binary logs!"
            send_discord_message "Hourly binary logs backup failed during compression."
            exit 1
        fi
    else
        echo "Failed to copy binary logs!"
        send_discord_message "Hourly binary logs backup failed."
        exit 1
    fi
}

# Function to copy the backup file to S3
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

# Function to clean up old backups and binary logs
clean_up_old_backups() {
    echo "Cleaning up local backups older than 8 days..."
    find "$HOST_BACKUP_DIR" -type f -name "*.7z" -mtime +8 -exec rm -f {} \;
    echo "Cleaning up old binary logs..."
    find "$CONTAINER_BACKUP_DIR" -type f -name "mysql-bin.*" -mtime +$BINARY_LOGS_RETENTION_DAYS -exec rm -f {} \;
    echo "Old backups and binary logs cleaned up successfully."
}

# Main script logic to decide between full and incremental backups
echo "Starting backup process..."
if [[ "$FORCE_BACKUP" == true ]]; then
    echo "Force backup triggered."
    create_full_backup
elif [[ "$CURRENT_HOUR" == "$FULL_BACKUP_HOUR" && "$CURRENT_MINUTE" == "00" ]]; then
    echo "Performing full backup..."
    create_full_backup
else
    echo "Performing incremental backup..."
    create_incremental_backup
fi

# Clean up old backups and binary logs
if [[ "$USE_S3" == false || $? -eq 0 ]]; then
    clean_up_old_backups
fi

exit 0
