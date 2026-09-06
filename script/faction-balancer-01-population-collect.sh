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

# Function to send a message to Discord (if needed for future notification)
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

# Step 1: Execute the internal script inside the container
log_message "INFO" "Calling internal population balance script inside the container"
if sudo docker exec vmangos-database /home/default/scripts/01-population-balance-collect.sh; then
    log_message "SUCCESS" "Population balance script executed successfully inside the container"
else
    log_message "ERROR" "Failed to execute population balance script inside the container"
    send_discord_message "Failed to execute population balance script inside the container."
    exit 1
fi

log_message "SUCCESS" "Script completed successfully"
