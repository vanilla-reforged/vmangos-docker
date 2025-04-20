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
    
    # Extract only the relevant lines and clean them
    players_info=$(echo "$server_info" | grep "Players online:" | sed 's/\r//g' | sed 's/^[[:space:]]*//')
    uptime_info=$(echo "$server_info" | grep "Server uptime:" | sed 's/\r//g' | sed 's/^[[:space:]]*//')
    
    # Only include the players and uptime info
    echo "$players_info"
    echo "$uptime_info"
    
    log_message "INFO" "Successfully retrieved server info"
    return 0
}

# Function to calculate last restart time
calculate_last_restart() {
    # Get the current time
    current_time=$(date +%s)
    
    # Extract uptime from server_info
    uptime_line=$(echo "$1" | grep "Server uptime:")
    
    # Parse the uptime line
    hours=0
    minutes=0
    seconds=0
    
    if [[ $uptime_line =~ ([0-9]+)[[:space:]]+Hours? ]]; then
        hours=${BASH_REMATCH[1]}
    fi
    
    if [[ $uptime_line =~ ([0-9]+)[[:space:]]+Minutes? ]]; then
        minutes=${BASH_REMATCH[1]}
    fi
    
    if [[ $uptime_line =~ ([0-9]+)[[:space:]]+Seconds? ]]; then
        seconds=${BASH_REMATCH[1]}
    fi
    
    # Calculate total uptime in seconds
    total_seconds=$(( (hours * 3600) + (minutes * 60) + seconds ))
    
    # Calculate restart timestamp
    restart_timestamp=$((current_time - total_seconds))
    
    # Format restart time
    restart_time=$(date -d "@$restart_timestamp" "+%Y-%m-%d %H:%M:%S")
    
    echo "$restart_time"
}

# Get server info
server_info=$(get_server_info)
status=$?

# Handle possible failure
if [ $status -ne 0 ] || [ -z "$server_info" ]; then
    log_message "ERROR" "Failed to get server info or server info is empty"
    server_info="Unable to retrieve server information. The server might be down."
fi

# Calculate last restart time
last_restart=$(calculate_last_restart "$server_info")

# Format date and time
current_date=$(date "+%Y-%m-%d")
current_time=$(date "+%H:%M:%S")

# Send to Discord if webhook is configured
if [ -n "$DISCORD_WEBHOOK" ]; then
    log_message "INFO" "Sending server info to Discord"
    message="**Server Status Report - $current_date $current_time**\\n\\n"
    
    # Parse the server info line by line and add each line properly formatted
    while IFS= read -r line; do
        # Add each line with proper Discord line breaks
        message+="${line}\\n"
    done <<< "$server_info"
    
    # Add the last restart with proper line break
    message+="Last restart: $last_restart"
    
    # Make the payload with proper JSON escaping
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
    echo -e "Last restart: $last_restart"
fi

log_message "SUCCESS" "Script completed"
