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
source ./../../.env-script  # Adjust to load .env-script from the project root using $DOCKER_DIRECTORY

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

# Function to remove old log entries
remove_old_entries() {
    local file="$1"
    local days="$2"
    local temp_file="${file}.tmp"
    local filename
    local lines_before
    local lines_after
    local lines_removed
    local cutoff_date

    filename=$(basename "$file")

    log_message "INFO" "Processing log file: $filename"

    if [ ! -f "$file" ]; then
        log_message "WARNING" "Log file not found: $file"
        return
    fi

    # Count lines before cleanup
    lines_before=$(wc -l < "$file")
    log_message "DEBUG" "Lines before cleanup: $lines_before in $filename"

    # Calculate the cutoff date
    cutoff_date=$(date -d "$days days ago" +%s)
    log_message "DEBUG" "Removing entries older than $(date -d "@$cutoff_date" '+%Y-%m-%d %H:%M:%S')"

    if awk -v cutoff="$cutoff_date" '
    {
        # Extract the timestamp from the start of the line
        match($0, /^([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})/, a)

        if (a[1] != "") {
            timestamp = a[1]

            # Convert timestamp to epoch seconds
            gsub(/[-: ]/, " ", timestamp)
            split(timestamp, t, " ")
            epoch = mktime(t[1] " " t[2] " " t[3] " " t[4] " " t[5] " " t[6])

            if (epoch >= cutoff) {
                print $0
            }
        } else {
            # If no timestamp is found, include the line
            print $0
        }
    }' "$file" > "$temp_file"; then

        # Count lines after cleanup
        lines_after=$(wc -l < "$temp_file")
        lines_removed=$((lines_before - lines_after))

        # Preserve ownership and permissions of the original log file
        chown --reference="$file" "$temp_file"
        chmod --reference="$file" "$temp_file"

        # Replace the original file with the cleaned file
        mv "$temp_file" "$file"

        log_message "SUCCESS" "Removed $lines_removed old entries from $filename"
    else
        rm -f "$temp_file"
        log_message "ERROR" "Failed to clean up $filename"
    fi
}

# Remove entries older than 21 days in 'mangos' logs (excluding 'honor')
log_message "INFO" "Starting cleanup of mangos logs"
for log_file in "$DOCKER_DIRECTORY/vol/logs/mangos/"*; do
    if [ "$(basename "$log_file")" != "honor" ] && [ -f "$log_file" ]; then
        remove_old_entries "$log_file" 21
    fi
done

# Remove entries older than 21 days in 'honor.log'
log_message "INFO" "Checking for honor logs"
if [ -f "$DOCKER_DIRECTORY/vol/logs/mangos/honor/honor.log" ]; then
    log_message "INFO" "Processing honor logs"
    remove_old_entries "$DOCKER_DIRECTORY/vol/logs/mangos/honor/honor.log" 21
else
    log_message "WARNING" "Honor log file not found, skipping"
fi

# Remove entries older than 21 days in 'realmd' logs
log_message "INFO" "Starting cleanup of realmd logs"
for log_file in "$DOCKER_DIRECTORY/vol/logs/realmd/"*; do
    if [ -f "$log_file" ]; then
        remove_old_entries "$log_file" 21
    fi
done

# Notify via Discord
send_discord_message "Log cleanup completed. Old entries have been removed from mangos and realmd logs."

log_message "SUCCESS" "Log cleanup process completed"
