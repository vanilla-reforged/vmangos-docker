#!/bin/bash

# Directories for logs
LOG_DIR="./resource_logs"
DB_LOG="$LOG_DIR/db_usage.log"
MANGOS_LOG="$LOG_DIR/mangos_usage.log"
REALMD_LOG="$LOG_DIR/realmd_usage.log"

# Time threshold (7 days in seconds)
SEVEN_DAYS_AGO=$(date -d '7 days ago' +%s)

# Function to calculate average usage
calculate_average() {
  log_file=$1

  # Filter entries within the last 7 days
  data=$(awk -F',' -v threshold=$SEVEN_DAYS_AGO '$1 >= threshold' $log_file)

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
    total_cpu=$(awk "BEGIN {print $total_cpu + $cpu_usage}")
    total_mem=$(awk "BEGIN {print $total_mem + $mem_usage}")
    count=$((count + 1))
  done <<< "$data"

  avg_cpu=$(awk "BEGIN {printf \"%.2f\", $total_cpu / $count}")
  avg_mem=$(awk "BEGIN {printf \"%.2f\", $total_mem / $count}")

  echo "$avg_cpu,$avg_mem"
}

# Calculate averages for each container
avg_db=$(calculate_average $DB_LOG)
avg_mangos=$(calculate_average $MANGOS_LOG)
avg_realmd=$(calculate_average $REALMD_LOG)

# Extract average CPU and memory usage
avg_cpu_db=$(echo $avg_db | cut -d',' -f1)
avg_mem_db=$(echo $avg_db | cut -d',' -f2)

avg_cpu_mangos=$(echo $avg_mangos | cut -d',' -f1)
avg_mem_mangos=$(echo $avg_mangos | cut -d',' -f2)

avg_cpu_realmd=$(echo $avg_realmd | cut -d',' -f1)
avg_mem_realmd=$(echo $avg_realmd | cut -d',' -f2)

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

# Update the set_resource_limits.sh script
sed -i "s/^RATIO_DB=.*/RATIO_DB=$RATIO_DB/" set_resource_limits.sh
sed -i "s/^RATIO_MANGOS=.*/RATIO_MANGOS=$RATIO_MANGOS/" set_resource_limits.sh
sed -i "s/^RATIO_REALMD=.*/RATIO_REALMD=$RATIO_REALMD/" set_resource_limits.sh

echo "Updated ratios in set_resource_limits.sh:"
echo "RATIO_DB=$RATIO_DB"
echo "RATIO_MANGOS=$RATIO_MANGOS"
echo "RATIO_REALMD=$RATIO_REALMD"

# Re-run set_resource_limits.sh to apply new ratios
./set_resource_limits.sh
