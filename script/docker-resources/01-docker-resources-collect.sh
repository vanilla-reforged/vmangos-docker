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

# Directories for storing logs
LOG_DIR="$DOCKER_DIRECTORY/vol/docker-resources"  # Adjusted to use $DOCKER_DIRECTORY for the correct log directory
DB_LOG="$LOG_DIR/db_usage.log"
MANGOS_LOG="$LOG_DIR/mangos_usage.log"
REALMD_LOG="$LOG_DIR/realmd_usage.log"
log_message "INFO" "Using log directory: $LOG_DIR"

# Ensure the log directory exists
if mkdir -p "$LOG_DIR"; then
    log_message "INFO" "Log directory ensured: $LOG_DIR"
else
    log_message "ERROR" "Failed to create log directory: $LOG_DIR"
fi

# Get current timestamp
timestamp=$(date +%s)
log_message "INFO" "Current timestamp: $timestamp ($(date -d @$timestamp '+%Y-%m-%d %H:%M:%S'))"

# Function to collect resource usage for a container
collect_usage() {
   container_name=$1
   log_file=$2
   
   # Check if the container is running
   if ! sudo docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
       log_message "WARNING" "Container $container_name is not running"
       echo "Warning: Container $container_name is not running." >> "${LOG_DIR}/error.log"
       return
   }
   
   log_message "INFO" "Collecting resource stats for container: $container_name"
   
   # Get container stats in JSON format
   stats=$(sudo docker stats --no-stream --format "{{json .}}" "$container_name" 2>/dev/null)
   
   # Check if stats were successfully retrieved
   if [ -z "$stats" ]; then
       log_message "WARNING" "Unable to collect stats for $container_name"
       echo "Warning: Unable to collect stats for $container_name." >> "${LOG_DIR}/error.log"
       return
   }
   
   # CPU collection removed
   
   mem_raw=$(echo "$stats" | jq -r '.MemUsage' | awk -F'/' '{print $1}' || echo "0MiB")
   
   # Check if the value is in GiB and convert to MiB if it is
   if [[ $mem_raw == *"GiB"* ]]; then
       mem_usage=$(echo "$mem_raw" | tr -d 'GiB' | awk '{printf "%.2f", $1 * 1024}')
       log_message "DEBUG" "Converted memory from GiB to MiB: $mem_raw -> $mem_usage MiB"
   else
       mem_usage=$(echo "$mem_raw" | tr -d 'MiB')
   }
   
   # If mem_usage is empty or not a number, set it to 0
   if ! [[ "$mem_usage" =~ ^[0-9]*\.?[0-9]*$ ]]; then
       log_message "WARNING" "Invalid memory usage value, setting to 0"
       mem_usage="0.00"
   }
   
   # Get human-readable timestamp
   human_timestamp=$(date +"%Y-%m-%d %H:%M:%S")
   
   # Append data to log file - removed CPU data
   echo "$human_timestamp,$timestamp,$mem_usage" >> "$log_file"
   log_message "INFO" "Recorded stats for $container_name - Memory: $mem_usage MiB"
   
   # Clean up old entries
   clean_old_entries "$log_file"
}

# Function to clean up old entries from a log file
clean_old_entries() {
  log_file=$1
  
  # Define the threshold (e.g., entries older than 8 days)
  threshold=$(date -d '8 days ago' +%s)
  log_message "INFO" "Cleaning entries older than 8 days (before $(date -d @$threshold '+%Y-%m-%d %H:%M:%S')) from $log_file"
  
  # Create a temporary file
  temp_file="${log_file}.tmp"
  
  # Filter the file to keep only entries newer than the threshold
  # This uses the timestamp field (2nd column) for comparison
  before_count=$(wc -l < "$log_file" 2>/dev/null || echo 0)
  awk -F',' -v threshold="$threshold" '$2 >= threshold' "$log_file" > "$temp_file"
  after_count=$(wc -l < "$temp_file" 2>/dev/null || echo 0)
  removed_count=$((before_count - after_count))
  
  # Check if the temporary file was created successfully
  if [ -s "$temp_file" ]; then
    mv "$temp_file" "$log_file"
    log_message "INFO" "Removed $removed_count old entries from $log_file"
  else
    # If the temp file is empty or wasn't created, log an error and don't modify the original
    log_message "WARNING" "Failed to clean old entries from $log_file"
    echo "Warning: Failed to clean old entries from $log_file" >> "${LOG_DIR}/error.log"
    rm -f "$temp_file"  # Remove the empty temp file if it exists
  fi
}

# Collect data for each container
log_message "INFO" "Starting resource data collection for containers"
collect_usage "vmangos-database" "$DB_LOG"
collect_usage "vmangos-mangos" "$MANGOS_LOG"
collect_usage "vmangos-realmd" "$REALMD_LOG"

log_message "SUCCESS" "Resource collection completed successfully"
