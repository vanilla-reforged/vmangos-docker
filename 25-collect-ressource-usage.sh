#!/bin/bash

# Directories for storing logs
LOG_DIR="./resource_logs"
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
  if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
    echo "Warning: Container $container_name is not running."
    return
  fi

  # Get container stats in JSON format
  stats=$(docker stats --no-stream --format "{{json .}}" "$container_name" 2>/dev/null)

  # Check if stats were successfully retrieved
  if [ -z "$stats" ]; then
    echo "Warning: Unable to collect stats for $container_name."
    return
  fi

  # Extract CPU and memory usage
  cpu_usage=$(echo "$stats" | jq -r '.CPUPerc' | tr -d '%' || echo "0")
  mem_usage=$(echo "$stats" | jq -r '.MemUsage' | awk -F'/' '{print $1}' | tr -d 'MiB' | tr -d 'GiB')

  # Handle potential errors in CPU or memory parsing
  if ! [[ "$cpu_usage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    cpu_usage="0"  # Default to 0 if parsing failed
  fi

  # Convert memory usage to MiB if necessary
  mem_unit=$(echo "$stats" | jq -r '.MemUsage' | awk -F'/' '{print $1}' | grep -o '[A-Za-z]*$')
  if [ "$mem_unit" == "GiB" ]; then
    mem_usage=$(awk "BEGIN {printf \"%.2f\", $mem_usage * 1024}")
  elif [ "$mem_unit" == "KiB" ]; then
    mem_usage=$(awk "BEGIN {printf \"%.2f\", $mem_usage / 1024}")
  elif [ "$mem_unit" == "B" ]; then
    mem_usage=$(awk "BEGIN {printf \"%.2f\", $mem_usage / 1048576}")
  fi

  # Append data to log file
  echo "$timestamp,$cpu_usage,$mem_usage" >> "$log_file"

  # Clean up old entries (e.g., older than 8 days)
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
