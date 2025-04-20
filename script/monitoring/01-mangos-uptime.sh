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

# Get server uptime
log_message "INFO" "Getting server info"
server_uptime_output=$(sudo docker exec vmangos-mangos bash -c "echo 'server info' | ./../bin/mangos-worldserver" 2>/dev/null | grep "Server uptime:")

if [ -z "$server_uptime_output" ]; then
    log_message "ERROR" "Failed to get server uptime"
    server_uptime="Server uptime: Unknown"
else
    server_uptime=$(echo "$server_uptime_output" | tr -d '\r' | sed 's/^[[:space:]]*//')
    log_message "INFO" "Server uptime: $server_uptime"
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
log_message "INFO" "Last restart: $last_restart"

# Get current server time
server_time=$(date "+%Y-%m-%d %H:%M:%S")
log_message "INFO" "Server time: $server_time"

# Create the Discord message
discord_message=$(cat <<EOF
$server_uptime
Last restart: $last_restart
Server time: $server_time
EOF
)

# Send to Discord if webhook is configured
if [ -n "$DISCORD_WEBHOOK" ]; then
    log_message "INFO" "Sending to Discord"
    
    # Create a JSON file with the payload
    cat > /tmp/discord_payload.json <<EOF
{"content":"$discord_message"}
EOF

    # Send the message
    curl_output=$(curl -s -H "Content-Type: application/json" \
                 -X POST \
                 --data @/tmp/discord_payload.json \
                 "$DISCORD_WEBHOOK" 2>&1)
    
    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Discord notification sent successfully"
    else
        log_message "ERROR" "Failed to send Discord notification: $curl_output"
    fi
    
    # Clean up
    rm -f /tmp/discord_payload.json
else
    log_message "WARNING" "Discord webhook not configured, printing to console"
    echo "$discord_message"
fi

log_message "SUCCESS" "Script completed"
