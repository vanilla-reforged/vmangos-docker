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
MIN_RESERVATION_DB=1      # 1 GB
MIN_RESERVATION_MANGOS=1  # 1 GB
MIN_RESERVATION_REALMD=0.1 # 100 MB

# Base CPU shares (default is 1024)
BASE_CPU_SHARES=1024

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

  # Extracting CPU and Memory usage
  data=$(awk -F',' -v threshold=$SEVEN_DAYS_AGO '$1 >= threshold {print $3 "," $4}' "$log_file")
  
  if [ -z "$data" ]; then
    echo "0,0"
    return
  fi

  total_cpu=0
  total_mem=0
  count=0

  while IFS=',' read -r cpu_usage mem_usage; do
    if [[ "$cpu_usage" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$mem_usage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      total_cpu=$(awk "BEGIN {print $total_cpu + $cpu_usage}")
      total_mem=$(awk "BEGIN {print $total_mem + $mem_usage}")
      count=$((count + 1))
    else
      echo "Warning: Invalid entry skipped: CPU=$cpu_usage, Memory=$mem_usage"
    fi
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

# Debugging output
echo "Average Memory Values: DB=$avg_mem_db, Mangos=$avg_mem_mangos, Realmd=$avg_mem_realmd"

# Ensure average memory values are valid
avg_mem_db=${avg_mem_db:-0.01}
avg_mem_mangos=${avg_mem_mangos:-0.01}
avg_mem_realmd=${avg_mem_realmd:-0.01}

total_avg_mem=$(awk "BEGIN {print ($avg_mem_db + $avg_mem_mangos + $avg_mem_realmd) / 1024}")
if [[ -z "$total_avg_mem" || "$total_avg_mem" == "NaN" ]]; then
  echo "Error: total_avg_mem calculation failed."
  total_avg_mem=1
fi

if [ "$(echo "$total_avg_mem == 0" | bc)" -eq 1 ]; then
  total_avg_mem=1
fi

# Calculate new ratios based on average memory usage
RATIO_DB=$(awk "BEGIN {printf \"%.2f\", $avg_mem_db / ($total_avg_mem * 1024)}")
RATIO_MANGOS=$(awk "BEGIN {printf \"%.2f\", $avg_mem_mangos / ($total_avg_mem * 1024)}")
RATIO_REALMD=$(awk "BEGIN {printf \"%.2f\", $avg_mem_realmd / ($total_avg_mem * 1024)}")

# Ensure ratios are not zero
RATIO_DB=${RATIO_DB:-0.01}
RATIO_MANGOS=${RATIO_MANGOS:-0.01}
RATIO_REALMD=${RATIO_REALMD:-0.01}

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

# Calculate dynamic CPU shares for each container based on usage ratios
cpu_shares_db=$(awk "BEGIN {printf \"%d\", 1024 * $RATIO_DB}")
cpu_shares_mangos=$(awk "BEGIN {printf \"%d\", 1024 * $RATIO_MANGOS}")
cpu_shares_realmd=$(awk "BEGIN {printf \"%d\", 1024 * $RATIO_REALMD}")

# Apply minimum constraint to ensure they are at least 5 times the base value
min_cpu_shares=$((5 * BASE_CPU_SHARES))

cpu_shares_db=$(awk "BEGIN {print ($cpu_shares_db < $min_cpu_shares) ? $min_cpu_shares : $cpu_shares_db}")
cpu_shares_mangos=$(awk "BEGIN {print ($cpu_shares_mangos < $min_cpu_shares) ? $min_cpu_shares : $cpu_shares_mangos}")
cpu_shares_realmd=$(awk "BEGIN {print ($cpu_shares_realmd < $min_cpu_shares) ? $min_cpu_shares : $cpu_shares_realmd}")

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
