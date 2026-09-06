#!/bin/bash

# Logger function for standardized logging
log_message() {
    local level="$1"
    local message="$2"
    local script_name=$(basename "$0")
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$script_name] [$level] $message" >&2
}

# Change to the directory where the script is located
cd "$(dirname "$0")" >/dev/null 2>&1
log_message "INFO" "Script started"

# Load environment variables from .env-script
log_message "INFO" "Loading environment variables"
source ./../../.env-script >/dev/null 2>&1

# Get disk space information
log_message "INFO" "Getting disk space information"

# Get disk usage for root filesystem (where Docker host typically stores data)
disk_info=$(df -h / | tail -1)
filesystem=$(echo "$disk_info" | awk '{print $1}')
size=$(echo "$disk_info" | awk '{print $2}')
used=$(echo "$disk_info" | awk '{print $3}')
available=$(echo "$disk_info" | awk '{print $4}')
use_percent=$(echo "$disk_info" | awk '{print $5}')

log_message "INFO" "Disk info - Size: $size, Used: $used, Available: $available, Use%: $use_percent"

# Get current server time
server_time=$(date "+%Y-%m-%d %H:%M:%S")
log_message "INFO" "Server time: $server_time"

# Send to Discord if webhook is configured
if [ -n "$DISCORD_WEBHOOK" ]; then
    log_message "INFO" "Sending to Discord"
    
    # Create Discord message with proper formatting
    discord_message="**Docker Host Disk Space Report**\\n"
    discord_message+="**Filesystem:** ${filesystem}\\n"
    discord_message+="**Total Size:** ${size}\\n"
    discord_message+="**Used:** ${used} (${use_percent})\\n"
    discord_message+="**Available:** ${available}\\n"
    discord_message+="**Server Time:** ${server_time}"
    
    # Create payload
    payload="{\"content\":\"$discord_message\"}"
    
    # Write to temp file
    echo "$payload" > /tmp/discord_payload.json
    
    # Send the message
    if curl -s -H "Content-Type: application/json" \
         -X POST \
         --data @/tmp/discord_payload.json \
         "$DISCORD_WEBHOOK" > /dev/null 2>&1; then
        log_message "SUCCESS" "Discord notification sent successfully"
    else
        log_message "ERROR" "Failed to send Discord notification"
    fi
    
    # Clean up
    rm -f /tmp/discord_payload.json
else
    log_message "WARNING" "Discord webhook not configured, printing to console"
    echo "Docker Host Disk Space Report"
    echo "Filesystem: $filesystem"
    echo "Total Size: $size"
    echo "Used: $used ($use_percent)"
    echo "Available: $available"
    echo "Server Time: $server_time"
fi

log_message "SUCCESS" "Script completed"
