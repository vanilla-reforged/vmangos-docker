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
source ./../../.env-script

# Configuration
HOST_BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"
CONTAINER_BACKUP_DIR="/vol/backup"
BACKUP_RETENTION_DAYS=8
log_message "INFO" "Using backup directory: $HOST_BACKUP_DIR"
log_message "INFO" "Backup retention period: $BACKUP_RETENTION_DAYS days"

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    log_message "INFO" "Sending Discord message: $message"
    if curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK"; then
        log_message "SUCCESS" "Discord message sent successfully"
    else
        log_message "ERROR" "Failed to send Discord message"
    fi
}

# Function to clean up old backups and binary logs
clean_up_old_backups() {
    # Calculate the cutoff date (8 days ago at midnight)
    local cutoff_date=$(date -d "$BACKUP_RETENTION_DAYS days ago" +%Y%m%d)
    local current_date=$(date +%Y%m%d)
    log_message "INFO" "Cutoff date for backups: $cutoff_date (current date: $current_date)"
    
    # Counter for deleted files
    local deleted_count=0
    local total_size=0
    
    # Find and delete old files based on their names (YYYYMMDD pattern)
    log_message "INFO" "Searching for backup files older than cutoff date"
    while IFS= read -r file; do
        # Extract date from filename using regex
        if [[ $file =~ [0-9]{8} ]]; then
            file_date="${BASH_REMATCH[0]}"
            if [[ "$file_date" < "$cutoff_date" ]]; then
                file_size=$(du -k "$file" | cut -f1)
                total_size=$((total_size + file_size))
                log_message "INFO" "Deleting old backup: $(basename "$file") (date: $file_date, size: $file_size KB)"
                rm -f "$file"
                ((deleted_count++))
            fi
        fi
    done < <(find "$HOST_BACKUP_DIR" -type f -name "*.7z")
    
    # Convert total size to MB for easier reading if it's over 1024 KB
    if [ "$total_size" -gt 1024 ]; then
        total_size_mb=$(echo "scale=2; $total_size/1024" | bc)
        log_message "SUCCESS" "Deleted $deleted_count backup files older than $BACKUP_RETENTION_DAYS days (total: $total_size_mb MB)"
        send_discord_message "Deleted $deleted_count backup files (files before $cutoff_date, total: $total_size_mb MB)"
    else
        log_message "SUCCESS" "Deleted $deleted_count backup files older than $BACKUP_RETENTION_DAYS days (total: $total_size KB)"
        send_discord_message "Deleted $deleted_count backup files (files before $cutoff_date, total: $total_size KB)"
    fi
}

# Execute cleanup
log_message "INFO" "Starting backup cleanup process"
clean_up_old_backups
log_message "SUCCESS" "Script completed successfully"
exit 0
