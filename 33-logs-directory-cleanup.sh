#!/bin/bash

# Function to remove old log entries
remove_old_entries() {
    local file="$1"
    local days="$2"
    local temp_file="${file}.tmp"

    awk -v cutoff="$(date -d "$days days ago" +%s)" '
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
    }' "$file" > "$temp_file" && mv "$temp_file" "$file"
}

# Remove entries older than 3 days in 'mangos' logs (excluding 'honor')
for log_file in vol/logs/mangos/*; do
    if [ "$(basename "$log_file")" != "honor" ] && [ -f "$log_file" ]; then
        remove_old_entries "$log_file" 3
    fi
done

# Remove entries older than 14 days in 'honor.log'
if [ -f "vol/logs/mangos/honor/honor.log" ]; then
    remove_old_entries "vol/logs/mangos/honor/honor.log" 14
fi

# Remove entries older than 7 days in 'realmd' logs
for log_file in vol/logs/realmd/*; do
    if [ -f "$log_file" ]; then
        remove_old_entries "$log_file" 7
    fi
done

echo "Old log entries removed."
