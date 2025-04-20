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

# Get current timestamp
timestamp=$(date +%s)
log_message "INFO" "Current timestamp: $timestamp ($(date -d @$timestamp '+%Y-%m-%d %H:%M:%S'))"

# Function to get server info from mangos container
get_server_info() {
    log_message "INFO" "Getting server info from vmangos-mangos container"
    
    # Check if the container is running
    if ! sudo docker ps --format "{{.Names}}" | grep -q "^vmangos-mangos$"; then
        log_message "WARNING" "Container vmangos-mangos is not running"
        return 1
    fi
    
    # Use expect to connect to the container and execute the server info command
    server_info=$(expect -c '
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
    ')
    
    # Check if we got any output
    if [ -z "$server_info" ]; then
        log_message "ERROR" "Failed to get server info"
        return 1
    fi
    
    # Extract the relevant information using grep/sed
    core_info=$(echo "$server_info" | grep "Core revision:" | sed 's/\r//g')
    players_info=$(echo "$server_info" | grep "Players online:" | sed 's/\r//g')
    uptime_info=$(echo "$server_info" | grep "Server uptime:" | sed 's/\r//g')
    
    # Combine the information
    echo -e "$core_info\n$players_info\n$uptime_info"
    
    log_message "INFO" "Successfully retrieved server info"
    return 0
}

# Get server info
server_info=$(get_server_info)
status=$?

# Handle possible failure
if [ $status -ne 0 ] || [ -z "$server_info" ]; then
    log_message "ERROR" "Failed to get server info or server info is empty"
    server_info="Unable to retrieve server information. The server might be down."
fi

# Format date and time
current_date=$(date "+%Y-%m-%d")
current_time=$(date "+%H:%M:%S")

# Function to properly escape JSON strings
json_escape() {
    printf '%s' "$1" | python -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# Send to Discord if webhook is configured
if [ -n "$DISCORD_WEBHOOK" ]; then
    log_message "INFO" "Sending server info to Discord"
    message="**Server Status Report - $current_date $current_time**\n\n"
    
    # Split server_info by line and add each line with proper formatting
    while IFS= read -r line; do
        message+="$line\n"
    done <<< "$server_info"
    
    # Make a simpler message that's less likely to have JSON issues
    payload="{\"content\":\"$message\"}"
    
    # Output payload to a temp file to avoid command line escaping issues
    echo "$payload" > /tmp/discord_payload.json
    
    if curl -s -H "Content-Type: application/json" \
         -X POST \
         --data @/tmp/discord_payload.json \
         "$DISCORD_WEBHOOK"; then
        log_message "SUCCESS" "Discord notification sent successfully"
    else
        log_message "ERROR" "Failed to send Discord notification"
    fi
    
    # Clean up
    rm -f /tmp/discord_payload.json
else
    log_message "WARNING" "Discord webhook not configured, skipping notification"
    # Print the info to console anyway
    echo -e "\nServer Status Report - $current_date $current_time"
    echo -e "$server_info"
fi

log_message "SUCCESS" "Script completed"
