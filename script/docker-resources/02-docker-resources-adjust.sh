#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables from .env-script
source ./../../.env-script  # Adjust to load .env-script from the project root using $DOCKER_DIRECTORY

# Directories for logs
LOG_DIR="$DOCKER_DIRECTORY/vol/docker-resources"  # Adjusted to use $DOCKER_DIRECTORY for the correct log directory
DB_LOG="$LOG_DIR/db_usage.log"
MANGOS_LOG="$LOG_DIR/mangos_usage.log"
REALMD_LOG="$LOG_DIR/realmd_usage.log"

# Time threshold (7 days ago in seconds)
SEVEN_DAYS_AGO=$(date -d '7 days ago' +%s)

# Define minimum reservations in gigabytes
MIN_RESERVATION_DB=1      # 1 GB
MIN_RESERVATION_MANGOS=1  # 1 GB
MIN_RESERVATION_REALMD=0.1 # 100 MB

# Base CPU shares (default is 1024)
BASE_CPU_SHARES=1024

# Function to calculate average usage
calculate_average() {
  local log_file=$1
  if [ ! -f "$log_file" ] || [ ! -s "$log_file" ]; then
    echo "0,0"
    return
  fi

  # Extracting CPU and Memory usage
  data=$(awk -F',' -v threshold=$SEVEN_DAYS_AGO '$1 >= threshold {print $3 "," $4}' "$log_file")
  
  local total_cpu=0
  local total_mem=0
  local count=0

  while IFS=',' read -r cpu_usage mem_usage; do
    if [[ "$cpu_usage" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$mem_usage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      total_cpu=$(echo "$total_cpu + $cpu_usage" | bc)
      total_mem=$(echo "$total_mem + $mem_usage" | bc)
      count=$((count + 1))
    fi
  done <<< "$data"

  if [ "$count" -eq 0 ]; then
    echo "0,0"
    return
  fi

  avg_cpu=$(echo "scale=2; $total_cpu / $count" | bc)
  avg_mem=$(echo "scale=2; $total_mem / $count" | bc)
  echo "$avg_cpu,$avg_mem"
}

# Function to send message to Discord
send_discord_message() {
  local message=$1
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"$message\"}" \
       "$DISCORD_WEBHOOK"
}

# Calculate averages for each container
avg_db=$(calculate_average "$DB_LOG")
avg_mangos=$(calculate_average "$MANGOS_LOG")
avg_realmd=$(calculate_average "$REALMD_LOG")

# Extract values from averages
avg_cpu_db=$(echo "$avg_db" | cut -d',' -f1)
avg_mem_db=$(echo "$avg_db" | cut -d',' -f2)

avg_cpu_mangos=$(echo "$avg_mangos" | cut -d',' -f1)
avg_mem_mangos=$(echo "$avg_mangos" | cut -d',' -f2)

avg_cpu_realmd=$(echo "$avg_realmd" | cut -d',' -f1)
avg_mem_realmd=$(echo "$avg_realmd" | cut -d',' -f2)

# Check for valid memory values
avg_mem_db=${avg_mem_db:-0.01}
avg_mem_mangos=${avg_mem_mangos:-0.01}
avg_mem_realmd=${avg_mem_realmd:-0.01}

# Calculate total average memory in GB
total_avg_mem=$(echo "scale=2; ($avg_mem_db + $avg_mem_mangos + $avg_mem_realmd) / 1024" | bc)
if [ "$(echo "$total_avg_mem <= 0" | bc)" -eq 1 ]; then
  total_avg_mem=1
fi

# Calculate new ratios based on average memory usage
RATIO_DB=$(echo "scale=2; $avg_mem_db / ($total_avg_mem * 1024)" | bc)
RATIO_MANGOS=$(echo "scale=2; $avg_mem_mangos / ($total_avg_mem * 1024)" | bc)
RATIO_REALMD=$(echo "scale=2; $avg_mem_realmd / ($total_avg_mem * 1024)" | bc)

# Ensure ratios are not zero
RATIO_DB=${RATIO_DB:-0.01}
RATIO_MANGOS=${RATIO_MANGOS:-0.01}
RATIO_REALMD=${RATIO_REALMD:-0.01}

# Update memory and swap limits based on new ratios
mem_reservation_db=$(echo "scale=2; if ($total_avg_mem * $RATIO_DB < $MIN_RESERVATION_DB) $MIN_RESERVATION_DB else $total_avg_mem * $RATIO_DB" | bc)
mem_reservation_mangos=$(echo "scale=2; if ($total_avg_mem * $RATIO_MANGOS < $MIN_RESERVATION_MANGOS) $MIN_RESERVATION_MANGOS else $total_avg_mem * $RATIO_MANGOS" | bc)
mem_reservation_realmd=$(echo "scale=2; if ($total_avg_mem * $RATIO_REALMD < $MIN_RESERVATION_REALMD) $MIN_RESERVATION_REALMD else $total_avg_mem * $RATIO_REALMD" | bc)

# Convert reservations to memory limits
mem_limit_db=$mem_reservation_db
mem_limit_mangos=$mem_reservation_mangos
mem_limit_realmd=$mem_reservation_realmd

# Function to update or add a variable in the .env file
update_env_variable() {
  var_name=$1
  var_value=$2
  if [ -z "$var_value" ]; then
    echo "Warning: Skipping update of $var_name as value is empty."
    return
  fi

  if grep -q "^${var_name}=" .env; then
    sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" .env
  else
    echo "${var_name}=${var_value}" >> .env
  fi
}

# Ensure the .env file exists
touch .env

# Update memory limits and swap limits
update_env_variable "MEM_RESERVATION_DB" "${mem_reservation_db}g"
update_env_variable "MEM_RESERVATION_MANGOS" "${mem_reservation_mangos}g"
update_env_variable "MEM_RESERVATION_REALMD" "${mem_reservation_realmd}g"

update_env_variable "MEM_LIMIT_DB" "${mem_limit_db}g"
update_env_variable "MEM_LIMIT_MANGOS" "${mem_limit_mangos}g"
update_env_variable "MEM_LIMIT_REALMD" "${mem_limit_realmd}g"

memswap_limit_db=$(echo "scale=2; 2 * $mem_limit_db" | bc)
memswap_limit_mangos=$(echo "scale=2; 2 * $mem_limit_mangos" | bc)
memswap_limit_realmd=$(echo "scale=2; 2 * $mem_limit_realmd" | bc)

update_env_variable "MEMSWAP_LIMIT_DB" "${memswap_limit_db}g"
update_env_variable "MEMSWAP_LIMIT_MANGOS" "${memswap_limit_mangos}g"
update_env_variable "MEMSWAP_LIMIT_REALMD" "${memswap_limit_realmd}g"

# Calculate dynamic CPU shares for each container based on usage ratios
cpu_shares_db=$(echo "scale=0; 1024 * $RATIO_DB" | bc)
cpu_shares_mangos=$(echo "scale=0; 1024 * $RATIO_MANGOS" | bc)
cpu_shares_realmd=$(echo "scale=0; 1024 * $RATIO_REALMD" | bc)

# Apply minimum constraint to ensure they are at least 5 times the base value
min_cpu_shares=$((5 * BASE_CPU_SHARES))

cpu_shares_db=$(echo "if ($cpu_shares_db < $min_cpu_shares) $min_cpu_shares else $cpu_shares_db" | bc)
cpu_shares_mangos=$(echo "if ($cpu_shares_mangos < $min_cpu_shares) $min_cpu_shares else $cpu_shares_mangos" | bc)
cpu_shares_realmd=$(echo "if ($cpu_shares_realmd < $min_cpu_shares) $min_cpu_shares else $cpu_shares_realmd" | bc)

# Update CPU shares in the .env file
update_env_variable "CPU_SHARES_DB" "$cpu_shares_db"
update_env_variable "CPU_SHARES_MANGOS" "$cpu_shares_mangos"
update_env_variable "CPU_SHARES_REALMD" "$cpu_shares_realmd"

# Clean up old entries in log files
cleanup_log() {
  log_file=$1
  if [ -f "$log_file" ]; then
    awk -F',' -v threshold=$SEVEN_DAYS_AGO '$1 >= threshold' "$log_file" > "${log_file}.tmp" && mv "${log_file}.tmp" "$log_file"
  fi
}

cleanup_log "$DB_LOG"
cleanup_log "$MANGOS_LOG"
cleanup_log "$REALMD_LOG"

# Send the updated .env values to Discord
env_values=$(grep -E "MEM_RESERVATION_DB|MEM_RESERVATION_MANGOS|MEM_RESERVATION_REALMD|MEM_LIMIT_DB|MEM_LIMIT_MANGOS|MEM_LIMIT_REALMD|MEMSWAP_LIMIT_DB|MEMSWAP_LIMIT_MANGOS|MEMSWAP_LIMIT_REALMD|CPU_SHARES_DB|CPU_SHARES_MANGOS|CPU_SHARES_REALMD" .env)
send_discord_message "Updated .env values:\n$env_values"

# Restart Docker Compose services to apply new environment variables
echo "Restarting Docker Compose services..."
if ! docker compose down; then
  echo "Error: Failed to bring down Docker Compose services."
  exit 1
fi

if ! docker compose up -d; then
  echo "Error: Failed to bring up Docker Compose services."
  exit 1
fi

echo "Docker environment restarted with updated variables."
