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

  # Get container stats in JSON format
  stats=$(docker stats --no-stream --format "{{json .}}" "$container_name")

  # Extract CPU and memory usage
  cpu_usage=$(echo "$stats" | jq -r '.CPUPerc' | tr -d '%')
  mem_usage=$(echo "$stats" | jq -r '.MemUsage' | awk -F'/' '{print $1}' | tr -d 'MiB' | tr -d 'GiB')

  # Convert memory usage to MiB if necessary
  mem_unit=$(echo "$stats" | jq -r '.MemUsage' | awk -F'/' '{print $1}' | grep -o '[A-Za-z]*$')
  if [ "$mem_unit" == "GiB" ]; then
    mem_usage=$(awk "BEGIN {printf \"%.2f\", $mem_usage * 1024}")
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
