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

# Use expect to get server info
log_message "INFO" "Getting server info"
server_info=$(expect <<EOF
    set timeout 10
    spawn sudo docker attach vmangos-mangos
    sleep 2
    send "server info\r"
    sleep 2
    expect {
        "server info" {
            expect -re "Server uptime:.*\r\n"
        }
    }
    send "\x10"
    sleep 1
    send "\x11"
    expect eof
EOF
)

# Extract the uptime line
server_uptime=$(echo "$server_info" | grep "Server uptime:" | tr -d '\r' | sed 's/^[[:space:]]*//')

if [ -z "$server_uptime" ]; then
    log_message "ERROR" "Failed to get server uptime"
    server_uptime="Server uptime: Unknown"
else
    log_message "INFO" "Got server uptime: $server_uptime"
fi

# Calculate last restart time
current_time=$(date +%s)
hours=0
minutes=0
seconds=0

if [[ "$server_uptime" =~ ([0-9]+)[[:space:]]+Hours ]]; then
    hours=${BASH_REMATCH[1]}
fi

if [[ "$server_uptime" =~ ([0-9]+)[[:space:]]+Minutes ]]; then
    minutes=${BASH_REMATCH[1]}
fi

if [[ "$server_uptime" =~ ([0-9]+)[[:space:]]+Seconds ]]; then
    seconds=${BASH_REMATCH[1]}
fi

total_seconds=$(( (hours * 3600) + (minutes * 60) + seconds ))
restart_timestamp=$((current_time - total_seconds))
last_restart=$(date -d "@$restart_timestamp" "+%Y-%m-%d %H:%M:%S")
log_message "INFO" "Calculated last restart: $last_restart"

# Get current server time
server_time=$(date "+%Y-%m-%d %H:%M:%S")
log_message "INFO" "Server time: $server_time"

# Send to Discord if webhook is configured
if [ -n "$DISCORD_WEBHOOK" ]; then
    log_message "INFO" "Sending to Discord"
    
    # Use proper Discord linebreak escaping
    discord_message="${server_uptime}\\n"
    discord_message+="Last restart: ${last_restart}\\n"
    discord_message+="Server time: ${server_time}"
    
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
    echo "$server_uptime"
    echo "Last restart: $last_restart"
    echo "Server time: $server_time"
fi

log_message "SUCCESS" "Script completed"
