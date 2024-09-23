#!/bin/bash

# Directories for storing logs
LOG_DIR="./vol/resource_logs"
DB_LOG="$LOG_DIR/db_usage.log"
MANGOS_LOG="$LOG_DIR/mangos_usage.log"
REALMD_LOG="$LOG_DIR/realmd_usage.log"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Check if jq is installed; if not, attempt to install it
install_jq() {
  if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Attempting to install jq..."
    if [ -x "$(command -v apt-get)" ]; then
      sudo apt-get update && sudo apt-get install -y jq
    elif [ -x "$(command -v yum)" ]; then
      sudo yum install -y jq
    elif [ -x "$(command -v dnf)" ]; then
      sudo dnf install -y jq
    elif [ -x "$(command -v brew)" ]; then
      brew install jq
    else
      echo "Error: Could not determine package manager or install jq. Please install jq manually."
      exit 1
    fi

    if ! command -v jq &> /dev/null; then
      echo "Error: jq installation failed. Please install jq manually."
      exit 1
    else
      echo "jq successfully installed."
    fi
  else
    echo "jq is already installed. Skipping installation."
  fi
}

# Install jq if not already installed
install_jq

# Get current timestamp
timestamp=$(date +%s)

# Function to collect resource usage for a container
collect_usage() {
  container_name=$1
  log_file=$2

  # Check if the container is running
  if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
    echo "Warning: Container $container_name is not running." >> "${LOG_DIR}/error.log"
    return
  fi

  # Get container stats in JSON format
  stats=$(docker stats --no-stream --format "{{json .}}" "$container_name" 2>/dev/null)

  # Check if stats were successfully retrieved
  if [ -z "$stats" ]; then
    echo "Warning: Unable to collect stats for $container_name." >> "${LOG_DIR}/error.log"
    return
  fi

  # Extract CPU and memory usage
  cpu_usage=$(echo "$stats" | jq -r '.CPUPerc' | tr -d '%' || echo "0")
  mem_usage=$(echo "$stats" | jq -r '.MemUsage' | awk -F'/' '{print $1}' | tr -d 'MiB' | tr -d 'GiB')

  # Convert memory usage to MiB if necessary
  mem_unit=$(echo "$stats" | jq -r '.MemUsage' | awk -F'/' '{print $1}' | grep -o '[A-Za-z]*$')
  case "$mem_unit" in
    GiB) mem_usage=$(awk "BEGIN {printf \"%.2f\", $mem_usage * 1024}") ;;
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
