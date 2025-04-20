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

# Function to get server info from mangos container
get_uptime_only() {
    log_message "INFO" "Getting server info from vmangos-mangos container"
    
    # Check if the container is running
    if ! sudo docker ps --format "{{.Names}}" | grep -q "^vmangos-mangos$"; then
        log_message "WARNING" "Container vmangos-mangos is not running"
        return 1
    fi
    
    # Use expect to run the command and capture output
    output_file="/tmp/mangos_uptime_$$.tmp"
    
    expect -c "
        set timeout 10
        spawn sudo docker attach vmangos-mangos
        sleep 2
        send \"server info\r\"
        sleep 2
        expect {
            \"server info\" {
                expect -re \"Server uptime:.*\r\n\"
            }
        }
        send \"\x10\"
        sleep 1
        send \"\x11\"
        expect eof
    " > "$output_file" 2>/dev/null
    
    # Check if we got any output
    if [ ! -s "$output_file" ]; then
        log_message "ERROR" "Failed to get server info"
        rm -f "$output_file"
        return 1
    fi
    
    # Extract only the uptime line
    uptime_line=$(grep -o "Server uptime:.*" "$output_file" | head -1 | sed 's/\r//g')
    
    # Clean up the temp file
    rm -f "$output_file"
    
    if [ -n "$uptime_line" ]; then
        echo "$uptime_line"
        log_message "INFO" "Successfully extracted uptime info"
        return 0
    else
        log_message "ERROR" "Failed to extract uptime info"
        return 1
    fi
}

# Function to calculate last restart time
calculate_last_restart() {
    # Get the current time
    current_time=$(date +%s)
    
    # Extract uptime from server_info
    uptime_line="$1"
    
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

# Get server uptime info
uptime_info=$(get_uptime_only)
status=$?

# Handle possible failure
if [ $status -ne 0 ] || [ -z "$uptime_info" ]; then
    log_message "ERROR" "Failed to get server uptime info"
    uptime_info="Server uptime: Unknown"
fi

# Calculate last restart time
last_restart=$(calculate_last_restart "$uptime_info")

# Get current server time
server_time=$(date "+%Y-%m-%d %H:%M:%S")

# Send to Discord if webhook is configured
if [ -n "$DISCORD_WEBHOOK" ]; then
    log_message "INFO" "Sending server info to Discord"
    
    # Create an array of exactly what we want to send
    discord_message_lines=(
        "$uptime_info"
        "Last restart: $last_restart"
        "Server time: $server_time"
    )
    
    # Join the array with Discord's newline escaping
    discord_message=$(printf "%s\\n" "${discord_message_lines[@]}" | sed 's/\\n$//')
    
    # Create the final payload
    payload="{\"content\":\"$discord_message\"}"
    
    # Output payload to a temp file
    payload_file="/tmp/discord_payload_$$.json"
    echo "$payload" > "$payload_file"
    
    # Send the message
    if curl -s -H "Content-Type: application/json" \
         -X POST \
         --data @"$payload_file" \
         "$DISCORD_WEBHOOK"; then
        log_message "SUCCESS" "Discord notification sent successfully"
    else
        log_message "ERROR" "Failed to send Discord notification"
    fi
    
    # Clean up
    rm -f "$payload_file"
else
    log_message "WARNING" "Discord webhook not configured, skipping notification"
    # Print the info to console anyway
    echo -e "$uptime_info"
    echo -e "Last restart: $last_restart"
    echo -e "Server time: $server_time"
fi

log_message "SUCCESS" "Script completed"
