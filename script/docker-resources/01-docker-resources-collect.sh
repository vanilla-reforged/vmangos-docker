#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables from .env-script
source ./../../.env-script  # Adjust to load .env-script from the project root using $DOCKER_DIRECTORY

# Directories for storing logs
LOG_DIR="$DOCKER_DIRECTORY/vol/docker-resources"  # Adjusted to use $DOCKER_DIRECTORY for the correct log directory
DB_LOG="$LOG_DIR/db_usage.log"
MANGOS_LOG="$LOG_DIR/mangos_usage.log"
REALMD_LOG="$LOG_DIR/realmd_usage.log"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Get current timestamp
timestamp=$(date +%s)

# Function to collect resource usage for a container
collect_usage() {
    container_name=$1
    log_file=$2
    
    # Check if the container is running
    if ! sudo docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo "Warning: Container $container_name is not running." >> "${LOG_DIR}/error.log"
        return
    fi
    
    # Get container stats in JSON format
    stats=$(sudo docker stats --no-stream --format "{{json .}}" "$container_name" 2>/dev/null)
    
    # Check if stats were successfully retrieved
    if [ -z "$stats" ]; then
        echo "Warning: Unable to collect stats for $container_name." >> "${LOG_DIR}/error.log"
        return
    fi
    
    # Extract CPU usage
    cpu_usage=$(echo "$stats" | jq -r '.CPUPerc' | tr -d '%' || echo "0")
    
    # Extract memory info - get unit first before stripping
    mem_string=$(echo "$stats" | jq -r '.MemUsage' | awk -F'/' '{print $1}')
    mem_unit=$(echo "$mem_string" | grep -o '[A-Za-z]*$')
    mem_usage=$(echo "$mem_string" | sed 's/[A-Za-z]*$//')
    
    # Convert memory usage to MiB if necessary
    case "$mem_unit" in
        GiB) mem_usage=$(awk "BEGIN {printf \"%.2f\", $mem_usage * 1024}") ;;
        MiB) mem_usage=$(awk "BEGIN {printf \"%.2f\", $mem_usage}") ;;
        KiB) mem_usage=$(awk "BEGIN {printf \"%.2f\", $mem_usage / 1024}") ;;
        B)   mem_usage=$(awk "BEGIN {printf \"%.2f\", $mem_usage / 1048576}") ;;
    esac
    
    # Get human-readable timestamp
    human_timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Append data to log file
    echo "$human_timestamp,$timestamp,$cpu_usage,$mem_usage" >> "$log_file"
    
    # Clean up old entries
    clean_old_entries "$log_file"
}

# Function to clean up old entries from a log file
clean_old_entries() {
  log_file=$1
  # Define the threshold (e.g., entries older than 8 days)
  threshold=$(date -d '8 days ago' +%s)
  # Keep only entries newer than the threshold
  awk -F',' -v threshold="$threshold" '$1 >= threshold' "$log_file" > "${log_file}.tmp" && mv "${log_file}.tmp" "$log_file"
}

# Collect data for each container
collect_usage "vmangos-database" "$DB_LOG"
collect_usage "vmangos-mangos" "$MANGOS_LOG"
collect_usage "vmangos-realmd" "$REALMD_LOG"
