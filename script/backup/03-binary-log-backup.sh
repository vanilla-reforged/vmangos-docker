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

# Load environment variables first
log_message "INFO" "Loading environment variables"
source ./../../.env-script

# Configuration (after environment is loaded)
DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK"
BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"
DISCORD_LOG_FILE="/tmp/discord_cumulative_log.txt"
log_message "INFO" "Using backup directory: $BACKUP_DIR"
log_message "INFO" "Using cumulative log file: $DISCORD_LOG_FILE"

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    log_message "INFO" "Sending Discord message"
    if curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK_URL"; then
        log_message "SUCCESS" "Discord message sent successfully"
    else
        log_message "ERROR" "Failed to send Discord message"
    fi
}

# Function to append a message to the cumulative log
append_to_cumulative_log() {
    local message=$1
    log_message "INFO" "Appending to cumulative log: $message"
    echo "[$(date)] $message" >> "$DISCORD_LOG_FILE"
}

# Function to send cumulative messages
send_cumulative_messages() {
    if [[ -f "$DISCORD_LOG_FILE" && -s "$DISCORD_LOG_FILE" ]]; then
        log_message "INFO" "Sending cumulative log messages to Discord"
        local messages
        messages=$(cat "$DISCORD_LOG_FILE")
        send_discord_message "Cumulative Update:\n$messages"
        > "$DISCORD_LOG_FILE"  # Clear the log file after sending
        log_message "INFO" "Cleared cumulative log file after sending"
    else
        log_message "INFO" "No cumulative messages to send (file empty or missing)"
    fi
}

# Step 1: Run the binary log backup script inside the container
log_message "INFO" "Executing binary log backup script inside the container"
if sudo docker exec vmangos-database /home/default/scripts/03-binary-log-backup.sh; then
    log_message "SUCCESS" "Binary log backup script executed successfully"
    
    # Step 2: Compress the binary logs
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    log_message "INFO" "Compressing the binary logs"
    if 7z a "$BACKUP_DIR/binary_logs_$TIMESTAMP.7z" "$BACKUP_DIR/mysql-bin.*"; then
        log_message "SUCCESS" "Binary logs compressed successfully"
        
        # Get compressed file size
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/binary_logs_$TIMESTAMP.7z" | cut -f1)
        log_message "INFO" "Binary logs backup size: $BACKUP_SIZE"
        
        # Step 3: Clean up uncompressed binary logs
        log_message "INFO" "Removing uncompressed binary logs"
        if eval rm -f "$BACKUP_DIR/mysql-bin.*"; then
            log_message "SUCCESS" "Uncompressed binary logs cleaned up successfully"
            append_to_cumulative_log "Incremental binary logs backup completed successfully (Size: $BACKUP_SIZE)"
        else
            log_message "ERROR" "Failed to clean up uncompressed binary logs"
            append_to_cumulative_log "Incremental binary logs backup failed during cleanup"
            exit 1
        fi
    else
        log_message "ERROR" "Failed to compress binary logs"
        append_to_cumulative_log "Incremental binary logs backup failed during compression"
        exit 1
    fi
else
    log_message "ERROR" "Failed to execute binary log backup script inside the container"
    append_to_cumulative_log "Incremental binary logs backup failed during the log copy"
    exit 1
fi

# Send cumulative messages only at 6 PM
CURRENT_HOUR=$(date +%H)
if [[ "$CURRENT_HOUR" == "18" ]]; then
    log_message "INFO" "Current hour is 18:00, sending cumulative messages"
    send_cumulative_messages
else
    log_message "INFO" "Current hour is $CURRENT_HOUR, not sending cumulative messages yet"
fi

log_message "INFO" "Script completed successfully"
