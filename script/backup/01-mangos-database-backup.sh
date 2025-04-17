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

# Run the backup script inside the container
log_message "INFO" "Executing backup inside container"
if sudo docker exec vmangos-database /home/default/scripts/01-mangos-database-backup.sh; then
    log_message "SUCCESS" "Backup script executed successfully inside container"
else
    log_message "ERROR" "Failed to execute backup inside container"
    exit 1
fi

log_message "INFO" "Script completed successfully"
