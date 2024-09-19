#!/bin/bash

# Directories for logs
LOG_DIR="./vol/resource_logs"
DB_LOG="$LOG_DIR/db_usage.log"
MANGOS_LOG="$LOG_DIR/mangos_usage.log"
REALMD_LOG="$LOG_DIR/realmd_usage.log"
CHANGE_LOG="$LOG_DIR/change_log.log"

# Time threshold (7 days ago in seconds)
SEVEN_DAYS_AGO=$(date -d '7 days ago' +%s)

# Define minimum reservations in gigabytes
MIN_RESERVATION_DB=1  # Example: 1 GB
MIN_RESERVATION_MANGOS=1  # Example: 1 GB
MIN_RESERVATION_REALMD=0.1  # Example: 100 MB

# Function to log changes
log_change() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$CHANGE_LOG"
}

# Function to calculate average usage
calculate_average() {
  log_file=$1
  if [ ! -f "$log_file" ] || [ ! -s "$log_file" ]; then
    echo "Warning: Log file $log_file is missing or empty."
    echo "0,0"
    return
  fi

  data=$(awk -F',' -v threshold=$SEVEN_DAYS_AGO '$1 >= threshold' "$log_file")
  if [ -z "$data" ]; then
    echo "0,0"
    return
  fi

  total_cpu=0
  total_mem=0
  count=0

  while IFS=',' read -r _ cpu_usage mem_usage; do
    if ! [[ "$cpu_usage" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! [[ "$mem_usage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      continue
    fi
    total_cpu=$(awk "BEGIN {print $total_cpu + $cpu_usage}")
    total_mem=$(awk "BEGIN {print $total_mem + $mem_usage}")
    count=$((count + 1))
  done <<< "$data"

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

avg_cpu_db=$(echo "$avg_db" | cut -d',' -f1)
avg_mem_db=$(echo "$avg_db" | cut -d',' -f2)

avg_cpu_mangos=$(echo "$avg_mangos" | cut -d',' -f1)
avg_mem_mangos=$(echo "$avg_mangos" | cut -d',' -f2)

avg_cpu_realmd=$(echo "$avg_realmd" | cut -d',' -f1)
avg_mem_realmd=$(echo "$avg_realmd" | cut -d',' -f2)

# Ensure average memory values are valid
if [[ -z "$avg_mem_db" || "$avg_mem_db" == "0" ]]; then avg_mem_db=0.01; fi  # Small default to avoid zero
if [[ -z "$avg_mem_mangos" || "$avg_mem_mangos" == "0" ]]; then avg_mem_mangos=0.01; fi
if [[ -z "$avg_mem_realmd" || "$avg_mem_realmd" == "0" ]]; then avg_mem_realmd=0.01; fi

total_avg_mem=$(awk "BEGIN {print ($avg_mem_db + $avg_mem_mangos + $avg_mem_realmd) / 1024}")
if [ "$(echo "$total_avg_mem == 0" | bc)" -eq 1 ]; then
  total_avg_mem=1
fi

# Calculate new ratios based on average memory usage
RATIO_DB=$(awk "BEGIN {printf \"%.2f\", $avg_mem_db / ($total_avg_mem * 1024)}")
RATIO_MANGOS=$(awk "BEGIN {printf \"%.2f\", $avg_mem_mangos / ($total_avg_mem * 1024)}")
RATIO_REALMD=$(awk "BEGIN {printf \"%.2f\", $avg_mem_realmd / ($total_avg_mem * 1024)}")

# Ensure ratios are not zero
if (( $(echo "$RATIO_DB == 0" | bc -l) )); then RATIO_DB=0.01; fi
if (( $(echo "$RATIO_MANGOS == 0" | bc -l) )); then RATIO_MANGOS=0.01; fi
if (( $(echo "$RATIO_REALMD == 0" | bc -l) )); then RATIO_REALMD=0.01; fi

# Update memory and swap limits based on new ratios
mem_reservation_db=$(awk "BEGIN {printf \"%.2f\", ($total_avg_mem * $RATIO_DB < $MIN_RESERVATION_DB) ? $MIN_RESERVATION_DB : $total_avg_mem * $RATIO_DB}")
mem_reservation_mangos=$(awk "BEGIN {printf \"%.2f\", ($total_avg_mem * $RATIO_MANGOS < $MIN_RESERVATION_MANGOS) ? $MIN_RESERVATION_MANGOS : $total_avg_mem * $RATIO_MANGOS}")
mem_reservation_realmd=$(awk "BEGIN {printf \"%.2f\", ($total_avg_mem * $RATIO_REALMD < $MIN_RESERVATION_REALMD) ? $MIN_RESERVATION_REALMD : $total_avg_mem * $RATIO_REALMD}")

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

# Update ratio variables
update_env_variable "RATIO_DB" "$RATIO_DB"
update_env_variable "RATIO_MANGOS" "$RATIO_MANGOS"
update_env_variable "RATIO_REALMD" "$RATIO_REALMD"

# Update memory limits and swap limits
update_env_variable "MEM_RESERVATION_DB" "${mem_reservation_db}g"
update_env_variable "MEM_RESERVATION_MANGOS" "${mem_reservation_mangos}g"
update_env_variable "MEM_RESERVATION_REALMD" "${mem_reservation_realmd}g"

update_env_variable "MEM_LIMIT_DB" "${mem_limit_db}g"
update_env_variable "MEM_LIMIT_MANGOS" "${mem_limit_mangos}g"
update_env_variable "MEM_LIMIT_REALMD" "${mem_limit_realmd}g"

memswap_limit_db=$(awk "BEGIN {print 2 * $mem_limit_db}")
memswap_limit_mangos=$(awk "BEGIN {print 2 * $mem_limit_mangos}")
memswap_limit_realmd=$(awk "BEGIN {print 2 * $mem_limit_realmd}")

update_env_variable "MEMSWAP_LIMIT_DB" "${memswap_limit_db}g"
update_env_variable "MEMSWAP_LIMIT_MANGOS" "${memswap_limit_mangos}g"
update_env_variable "MEMSWAP_LIMIT_REALMD" "${memswap_limit_realmd}g"

cpu_shares_db=$(awk "BEGIN {printf \"%d\", 1024 * $RATIO_DB}")
cpu_shares_mangos=$(awk "BEGIN {printf \"%d\", 1024 * $RATIO_MANGOS}")
cpu_shares_realmd=$(awk "BEGIN {printf \"%d\", 1024 * $RATIO_REALMD}")

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

# Update resource limits in .env file
echo "Updated resource limits in .env file."

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
