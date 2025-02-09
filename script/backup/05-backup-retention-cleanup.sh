#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables from .env-script
source ./../../.env-script

# Configuration
HOST_BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"
CONTAINER_BACKUP_DIR="/vol/backup"
BACKUP_RETENTION_DAYS=8

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK"
}

# Function to clean up old backups and binary logs
clean_up_old_backups() {
    # Calculate the cutoff date (8 days ago at midnight)
    local cutoff_date=$(date -d "$BACKUP_RETENTION_DAYS days ago" +%Y%m%d)
    local current_date=$(date +%Y%m%d)
    
    # Counter for deleted files
    local deleted_count=0
    
    # Find and delete old files based on their names (YYYYMMDD pattern)
    while IFS= read -r file; do
        # Extract date from filename using regex
        if [[ $file =~ [0-9]{8} ]]; then
            file_date="${BASH_REMATCH[0]}"
            if [[ "$file_date" < "$cutoff_date" ]]; then
                rm -f "$file"
                ((deleted_count++))
            fi
        fi
    done < <(find "$HOST_BACKUP_DIR" -type f -name "*.7z")
    
    echo "Deleted $deleted_count backup files older than $BACKUP_RETENTION_DAYS days"
    send_discord_message "Deleted $deleted_count backup files (files before $cutoff_date)"
}

# Execute cleanup
clean_up_old_backups
exit 0
