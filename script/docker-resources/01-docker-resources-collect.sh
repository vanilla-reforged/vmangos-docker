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
   
   cpu_raw=$(echo "$stats" | jq -r '.CPUPerc' || echo "0%")
   # Remove percentage sign and convert to a proper number format
   # Use 4 decimal places to capture small values like 0.0909
   cpu_usage=$(echo "$cpu_raw" | tr -d '%' | awk '{printf "%.4f", $0}')
   
   # If cpu_usage is empty or not a number, set it to 0
   if ! [[ "$cpu_usage" =~ ^[0-9]*\.?[0-9]*$ ]]; then
       cpu_usage="0.0000"
   fi
   
   # For database container, normalize CPU usage if needed
   if [[ "$container_name" == "vmangos-database" ]]; then
       # Get the reported CPU value and ensure it's reasonable
       # If it seems too high, adjust it - but preserve original behavior
       if (( $(echo "$cpu_usage > 100" | bc -l) )); then
           # Get number of CPUs on the host system
           cpu_count=$(grep -c ^processor /proc/cpuinfo)
           # Only normalize if cpu_count is greater than 0
           if [ "$cpu_count" -gt 0 ]; then
               cpu_usage=$(echo "$cpu_usage / $cpu_count" | bc -l | awk '{printf "%.4f", $0}')
           fi
       fi
   fi
   
   mem_raw=$(echo "$stats" | jq -r '.MemUsage' | awk -F'/' '{print $1}' || echo "0MiB")
   
   # Check if the value is in GiB and convert to MiB if it is
   if [[ $mem_raw == *"GiB"* ]]; then
       mem_usage=$(echo "$mem_raw" | tr -d 'GiB' | awk '{printf "%.2f", $1 * 1024}')
   else
       mem_usage=$(echo "$mem_raw" | tr -d 'MiB')
   fi
   
   # If mem_usage is empty or not a number, set it to 0
   if ! [[ "$mem_usage" =~ ^[0-9]*\.?[0-9]*$ ]]; then
       mem_usage="0.00"
   fi
   
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
  
  # Create a temporary file
  temp_file="${log_file}.tmp"
  
  # Filter the file to keep only entries newer than the threshold
  # This uses the timestamp field (2nd column) for comparison
  awk -F',' -v threshold="$threshold" '$2 >= threshold' "$log_file" > "$temp_file"
  
  # Check if the temporary file was created successfully
  if [ -s "$temp_file" ]; then
    mv "$temp_file" "$log_file"
  else
    # If the temp file is empty or wasn't created, log an error and don't modify the original
    echo "Warning: Failed to clean old entries from $log_file" >> "${LOG_DIR}/error.log"
    rm -f "$temp_file"  # Remove the empty temp file if it exists
  fi
}
# Collect data for each container
collect_usage "vmangos-database" "$DB_LOG"
collect_usage "vmangos-mangos" "$MANGOS_LOG"
collect_usage "vmangos-realmd" "$REALMD_LOG"
