#!/bin/bash

# Load environment variables
source "$(dirname "$0")/.env-script"

# Configuration
DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK"  # Discord webhook URL
BACKUP_DIR="./vol/backup"  # Backup directory
CONTAINER_NAME="vmangos-database"  # Docker container name
DB_USER="mangos"  # Database username
DB_PASS="$MYSQL_ROOT_PASSWORD"  # Database password sourced from .env-script

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK_URL"
}

# Function to create a full SQL dump (characters, logs, realmd)
create_full_backup() {
    echo "Creating full SQL dump inside the container..."
    
    # Dump the specific databases
    docker exec $CONTAINER_NAME bash -c "mariadb-dump --user=$DB_USER --password=$DB_PASS --databases characters logs realmd > /vol/backup/full_backup.sql"
    
    if [[ $? -eq 0 ]]; then
        echo "Full SQL dump created successfully inside the container."

        # Compress the SQL dump
        echo "Compressing full SQL dump..."
        7z a "$BACKUP_DIR/full_backup_$(date +%Y%m%d%H%M%S).7z" "$BACKUP_DIR/full_backup.sql"
        
        if [[ $? -eq 0 ]]; then
            echo "Full SQL dump compressed successfully."
            
            # Remove the uncompressed full_backup.sql
            rm -f "$BACKUP_DIR/full_backup.sql"
            
            # Send Discord notification
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

# Execute the backup function
create_full_backup
