#!/bin/bash

# Directories for logs
LOG_DIR="./vol/resource_logs"
DB_LOG="$LOG_DIR/db_usage.log"
MANGOS_LOG="$LOG_DIR/mangos_usage.log"
REALMD_LOG="$LOG_DIR/realmd_usage.log"

# Time threshold (7 days ago in seconds)
SEVEN_DAYS_AGO=$(date -d '7 days ago' +%s)

# Function to calculate average usage
calculate_average() {
  log_file=$1

  # Check if log file exists and is not empty
  if [ ! -f "$log_file" ] || [ ! -s "$log_file" ]; then
    echo "Warning: Log file $log_file is missing or empty."
    echo "0,0"
    return
  fi

  # Filter entries within the last 7 days
  data=$(awk -F',' -v threshold=$SEVEN_DAYS_AGO '$1 >= threshold' "$log_file")

  # Check if data exists
  if [ -z "$data" ]; then
    echo "0,0"
    return
  fi

  # Calculate averages
  total_cpu=0
  total_mem=0
  count=0

  while IFS=',' read -r timestamp cpu_usage mem_usage; do
    # Validate the data format
    if ! [[ "$cpu_usage" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! [[ "$mem_usage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      continue
    fi

    total_cpu=$(awk "BEGIN {print $total_cpu + $cpu_usage}")
    total_mem=$(awk "BEGIN {print $total_mem + $mem_usage}")
    count=$((count + 1))
  done <<< "$data"

  # Avoid division by zero
  if [ "$count" -eq 0 ]; then
    echo "0,0"
    return
  fi

  avg_cpu=$(awk "BEGIN {printf \"%.2f\", $total_cpu / $count}")
  avg_mem=$(awk "BEGIN {printf \"%.2f\", $total_mem / $count}")

  echo "$avg_cpu,$avg_mem"
}

# Calculate averages for each container
avg_db=$(calculate_average "$DB_LOG")
avg_mangos=$(calculate_average "$MANGOS_LOG")
avg_realmd=$(calculate_average "$REALMD_LOG")

# Extract average CPU and memory usage
avg_cpu_db=$(echo "$avg_db" | cut -d',' -f1)
avg_mem_db=$(echo "$avg_db" | cut -d',' -f2)

avg_cpu_mangos=$(echo "$avg_mangos" | cut -d',' -f1)
avg_mem_mangos=$(echo "$avg_mangos" | cut -d',' -f2)

avg_cpu_realmd=$(echo "$avg_realmd" | cut -d',' -f1)
avg_mem_realmd=$(echo "$avg_realmd" | cut -d',' -f2)

# Total average memory usage
total_avg_mem=$(awk "BEGIN {print $avg_mem_db + $avg_mem_mangos + $avg_mem_realmd}")

# Avoid division by zero
if [ "$(echo "$total_avg_mem == 0" | bc)" -eq 1 ]; then
  total_avg_mem=1
fi

# Calculate new ratios based on average memory usage
RATIO_DB=$(awk "BEGIN {printf \"%.2f\", $avg_mem_db / $total_avg_mem}")
RATIO_MANGOS=$(awk "BEGIN {printf \"%.2f\", $avg_mem_mangos / $total_avg_mem}")
RATIO_REALMD=$(awk "BEGIN {printf \"%.2f\", $avg_mem_realmd / $total_avg_mem}")

echo "Calculated new ratios:"
echo "RATIO_DB=$RATIO_DB"
echo "RATIO_MANGOS=$RATIO_MANGOS"
echo "RATIO_REALMD=$RATIO_REALMD"

# Function to update or add a variable in the .env file
update_env_variable() {
  var_name=$1
  var_value=$2
  if grep -q "^${var_name}=" .env; then
    # Variable exists, update it
    sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" .env
  else
    # Variable doesn't exist, append it
    # Ensure the .env file ends with a newline before appending
    if [ -s .env ] && [ -n "$(tail -c1 .env)" ]; then
      echo "" >> .env
    fi
    echo "${var_name}=${var_value}" >> .env
  fi
}

# Ensure the .env file exists
touch .env

# Update or add the ratio variables in the .env file
update_env_variable "RATIO_DB" "$RATIO_DB"
update_env_variable "RATIO_MANGOS" "$RATIO_MANGOS"
update_env_variable "RATIO_REALMD" "$RATIO_REALMD"

# Update memory limits and swap limits based on new ratios and average usage
mem_reservation_db=$(awk "BEGIN {printf \"%.0f\", $total_avg_mem * $RATIO_DB}")
mem_reservation_mangos=$(awk "BEGIN {printf \"%.0f\", $total_avg_mem * $RATIO_MANGOS}")
mem_reservation_realmd=$(awk "BEGIN {printf \"%.0f\", $total_avg_mem * $RATIO_REALMD}")

mem_limit_db=$mem_reservation_db
mem_limit_mangos=$mem_reservation_mangos
mem_limit_realmd=$mem_reservation_realmd

memswap_limit_db=$(awk "BEGIN {print 2 * $mem_limit_db}")
memswap_limit_mangos=$(awk "BEGIN {print 2 * $mem_limit_mangos}")
memswap_limit_realmd=$(awk "BEGIN {print 2 * $mem_limit_realmd}")

# Convert memory values to bytes with 'b' suffix
mem_reservation_db_limit="${mem_reservation_db}b"
mem_reservation_mangos_limit="${mem_reservation_mangos}b"
mem_reservation_realmd_limit="${mem_reservation_realmd}b"

mem_limit_db_limit="${mem_limit_db}b"
mem_limit_mangos_limit="${mem_limit_mangos}b"
mem_limit_realmd_limit="${mem_limit_realmd}b"

memswap_limit_db_limit="${memswap_limit_db}b"
memswap_limit_mangos_limit="${memswap_limit_mangos}b"
memswap_limit_realmd_limit="${memswap_limit_realmd}b"

# Update or add resource reservation, limit, and swap limit variables in the .env file
update_env_variable "MEM_RESERVATION_DB" "${mem_reservation_db_limit}"
update_env_variable "MEM_RESERVATION_MANGOS" "${mem_reservation_mangos_limit}"
update_env_variable "MEM_RESERVATION_REALMD" "${mem_reservation_realmd_limit}"

update_env_variable "MEM_LIMIT_DB" "${mem_limit_db_limit}"
update_env_variable "MEM_LIMIT_MANGOS" "${mem_limit_mangos_limit}"
update_env_variable "MEM_LIMIT_REALMD" "${mem_limit_realmd_limit}"

update_env_variable "MEMSWAP_LIMIT_DB" "${memswap_limit_db_limit}"
update_env_variable "MEMSWAP_LIMIT_MANGOS" "${memswap_limit_mangos_limit}"
update_env_variable "MEMSWAP_LIMIT_REALMD" "${memswap_limit_realmd_limit}"

echo "Updated memory reservations, limits, and swap limits in .env file."

# Re-run set_resource_limits.sh to apply new ratios
./05-set-ressource-limits.sh

# Function to clean up old entries in a log file
cleanup_log() {
  log_file=$1
  # Keep only entries with timestamp >= SEVEN_DAYS_AGO
  awk -F',' -v threshold=$SEVEN_DAYS_AGO '$1 >= threshold' "$log_file" > "${log_file}.tmp" && mv "${log_file}.tmp" "$log_file"
}

# Clean up each log file after adjustment
cleanup_log "$DB_LOG"
cleanup_log "$MANGOS_LOG"
cleanup_log "$REALMD_LOG"

# Restart Docker environment to apply the new variables
echo "Restarting Docker environment to apply new .env variables..."
docker compose down
docker compose up -d

echo "Docker environment restarted with updated variables."
