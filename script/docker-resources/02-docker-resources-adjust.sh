#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables from .env-script
source ./../../.env-script

# Get total host memory and calculate 75% available memory
TOTAL_HOST_MEMORY=$(free -g | awk '/^Mem:/{print $2}')
AVAILABLE_MEMORY=$(echo "scale=2; $TOTAL_HOST_MEMORY * 0.75" | bc)

# Directories for logs
LOG_DIR="$DOCKER_DIRECTORY/vol/docker-resources"
DB_LOG="$LOG_DIR/db_usage.log"
MANGOS_LOG="$LOG_DIR/mangos_usage.log"
REALMD_LOG="$LOG_DIR/realmd_usage.log"

echo "Debug - Log Files:"
echo "DB Log: $DB_LOG"
echo "Mangos Log: $MANGOS_LOG"
echo "Realmd Log: $REALMD_LOG"

# Time threshold (7 days ago in seconds)
SEVEN_DAYS_AGO=$(date -d '7 days ago' +%s)

# Define minimum reservations in gigabytes
MIN_RESERVATION_DB=0.5      # 500 MB
MIN_RESERVATION_MANGOS=1.5  # 1.5 GB
MIN_RESERVATION_REALMD=0.1 # 100 MB

# Calculate total minimum reservations
TOTAL_MIN_RESERVATION=$(echo "scale=2; $MIN_RESERVATION_DB + $MIN_RESERVATION_MANGOS + $MIN_RESERVATION_REALMD" | bc)

# Calculate remaining memory after minimums
REMAINING_MEMORY=$(echo "scale=2; $AVAILABLE_MEMORY - $TOTAL_MIN_RESERVATION" | bc)

# Function to calculate average usage
calculate_average() {
    local log_file=$1
    if [ ! -f "$log_file" ] || [ ! -s "$log_file" ]; then
        echo "0,0"
        return
    fi

    # Use awk to properly process the log file
    # Format: timestamp,epoch,cpu,memory
    local result=$(awk -F',' -v threshold=$SEVEN_DAYS_AGO '
        $2 >= threshold { 
            cpu_sum += $3
            mem_sum += $4
            count++
        }
        END {
            if (count > 0) {
                printf "%.2f,%.2f", cpu_sum/count, mem_sum/count
            } else {
                print "0,0"
            }
        }' "$log_file")

    echo "$result"
}

# Get averages
echo "Debug - Calculating averages from logs..."
avg_db=$(calculate_average "$DB_LOG")
avg_mangos=$(calculate_average "$MANGOS_LOG")
avg_realmd=$(calculate_average "$REALMD_LOG")

# Extract memory values with validation
avg_mem_db=$(echo "$avg_db" | cut -d',' -f2 | grep -E '^[0-9]*\.?[0-9]+$' || echo "0")
avg_mem_mangos=$(echo "$avg_mangos" | cut -d',' -f2 | grep -E '^[0-9]*\.?[0-9]+$' || echo "0")
avg_mem_realmd=$(echo "$avg_realmd" | cut -d',' -f2 | grep -E '^[0-9]*\.?[0-9]+$' || echo "0")

echo "Debug - Raw Memory Values:"
echo "DB Memory: $avg_mem_db MB"
echo "Mangos Memory: $avg_mem_mangos MB"
echo "Realmd Memory: $avg_mem_realmd MB"

# Calculate total memory usage for ratio calculation
total_mem_usage=$(echo "scale=2; $avg_mem_db + $avg_mem_mangos + $avg_mem_realmd" | bc)

echo "Debug - Total Memory Usage: $total_mem_usage MB"

# Calculate ratios
if [ "$(echo "$total_mem_usage > 0" | bc)" -eq 1 ]; then
    ratio_db=$(echo "scale=4; $avg_mem_db / $total_mem_usage" | bc)
    ratio_mangos=$(echo "scale=4; $avg_mem_mangos / $total_mem_usage" | bc)
    ratio_realmd=$(echo "scale=4; $avg_mem_realmd / $total_mem_usage" | bc)
    echo "Debug - Calculated ratios from logs"
else
    # Default ratios if no usage data
    ratio_db=0.25
    ratio_mangos=0.70
    ratio_realmd=0.05
    echo "Debug - Using default ratios due to zero total memory usage"
fi

echo "Debug - Memory Ratios:"
echo "DB Ratio: $ratio_db"
echo "Mangos Ratio: $ratio_mangos"
echo "Realmd Ratio: $ratio_realmd"

# Distribute remaining memory according to ratios
extra_db=$(echo "scale=2; $REMAINING_MEMORY * $ratio_db" | bc)
extra_mangos=$(echo "scale=2; $REMAINING_MEMORY * $ratio_mangos" | bc)
extra_realmd=$(echo "scale=2; $REMAINING_MEMORY * $ratio_realmd" | bc)

echo "Debug - Extra Memory Distribution:"
echo "DB Extra: $extra_db GB"
echo "Mangos Extra: $extra_mangos GB"
echo "Realmd Extra: $extra_realmd GB"

# Add minimums to get final allocations
mem_reservation_db=$(echo "scale=2; $MIN_RESERVATION_DB + $extra_db" | bc)
mem_reservation_mangos=$(echo "scale=2; $MIN_RESERVATION_MANGOS + $extra_mangos" | bc)
mem_reservation_realmd=$(echo "scale=2; $MIN_RESERVATION_REALMD + $extra_realmd" | bc)

# Set memory limits equal to reservations
mem_limit_db=$mem_reservation_db
mem_limit_mangos=$mem_reservation_mangos
mem_limit_realmd=$mem_reservation_realmd

# Extract CPU values and calculate shares
avg_cpu_db=$(echo "$avg_db" | cut -d',' -f1)
avg_cpu_mangos=$(echo "$avg_mangos" | cut -d',' -f1)
avg_cpu_realmd=$(echo "$avg_realmd" | cut -d',' -f1)

total_cpu=$(echo "scale=2; $avg_cpu_db + $avg_cpu_mangos + $avg_cpu_realmd" | bc)

# Calculate CPU shares based on usage
BASE_CPU_SHARES=1024  # Default Docker CPU shares
MAX_MULTIPLIER=30     # Maximum multiplier for shares

if [ "$(echo "$total_cpu > 0" | bc)" -eq 1 ]; then
    cpu_ratio_db=$(echo "scale=4; $avg_cpu_db / $total_cpu" | bc)
    cpu_ratio_mangos=$(echo "scale=4; $avg_cpu_mangos / $total_cpu" | bc)
    cpu_ratio_realmd=$(echo "scale=4; $avg_cpu_realmd / $total_cpu" | bc)
    
    # Calculate shares with new formula:
    # BASE_CPU_SHARES + (ratio * (MAX_MULTIPLIER-1) * BASE_CPU_SHARES)
    # This ensures minimum of BASE_CPU_SHARES and maximum of (MAX_MULTIPLIER * BASE_CPU_SHARES)
    cpu_shares_db=$(echo "$BASE_CPU_SHARES + ($cpu_ratio_db * ($MAX_MULTIPLIER - 1) * $BASE_CPU_SHARES)/1" | bc)
    cpu_shares_mangos=$(echo "$BASE_CPU_SHARES + ($cpu_ratio_mangos * ($MAX_MULTIPLIER - 1) * $BASE_CPU_SHARES)/1" | bc)
    cpu_shares_realmd=$(echo "$BASE_CPU_SHARES + ($cpu_ratio_realmd * ($MAX_MULTIPLIER - 1) * $BASE_CPU_SHARES)/1" | bc)
else
    # If no CPU usage data, use default shares
    cpu_shares_db=$BASE_CPU_SHARES
    cpu_shares_mangos=$BASE_CPU_SHARES
    cpu_shares_realmd=$BASE_CPU_SHARES
fi

# Function to update or add a variable in the .env file
update_env_variable() {
    var_name=$1
    var_value=$2
    env_file="./../../.env"
    
    if [ -z "$var_value" ]; then
        echo "Warning: Skipping update of $var_name as value is empty."
        return
    fi

    if grep -q "^${var_name}=" "$env_file"; then
        sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" "$env_file"
    else
        echo "${var_name}=${var_value}" >> "$env_file"
    fi
}

# Ensure the .env file exists
touch ./../../.env

# Update all values
update_env_variable "MEM_RESERVATION_DB" "${mem_reservation_db}g"
update_env_variable "MEM_RESERVATION_MANGOS" "${mem_reservation_mangos}g"
update_env_variable "MEM_RESERVATION_REALMD" "${mem_reservation_realmd}g"

update_env_variable "MEM_LIMIT_DB" "${mem_limit_db}g"
update_env_variable "MEM_LIMIT_MANGOS" "${mem_limit_mangos}g"
update_env_variable "MEM_LIMIT_REALMD" "${mem_limit_realmd}g"

# Calculate and update swap limits (2x memory limits)
memswap_limit_db=$(echo "scale=2; 2 * $mem_limit_db" | bc)
memswap_limit_mangos=$(echo "scale=2; 2 * $mem_limit_mangos" | bc)
memswap_limit_realmd=$(echo "scale=2; 2 * $mem_limit_realmd" | bc)

update_env_variable "MEMSWAP_LIMIT_DB" "${memswap_limit_db}g"
update_env_variable "MEMSWAP_LIMIT_MANGOS" "${memswap_limit_mangos}g"
update_env_variable "MEMSWAP_LIMIT_REALMD" "${memswap_limit_realmd}g"

update_env_variable "CPU_SHARES_DB" "$cpu_shares_db"
update_env_variable "CPU_SHARES_MANGOS" "$cpu_shares_mangos"
update_env_variable "CPU_SHARES_REALMD" "$cpu_shares_realmd"

# Clean up old log entries
cleanup_log() {
    log_file=$1
    if [ -f "$log_file" ]; then
        awk -F',' -v threshold=$SEVEN_DAYS_AGO '$1 >= threshold' "$log_file" > "${log_file}.tmp" && mv "${log_file}.tmp" "$log_file"
    fi
}

cleanup_log "$DB_LOG"
cleanup_log "$MANGOS_LOG"
cleanup_log "$REALMD_LOG"

# Print summary
echo "Memory Allocation Summary:"
echo "Total Host Memory: ${TOTAL_HOST_MEMORY}GB"
echo "Available Memory (75%): ${AVAILABLE_MEMORY}GB"
echo "Total Minimum Reservation: ${TOTAL_MIN_RESERVATION}GB"
echo "Remaining for Distribution: ${REMAINING_MEMORY}GB"
echo "Usage Ratios (DB:Mangos:Realmd): ${ratio_db}:${ratio_mangos}:${ratio_realmd}"
echo ""
echo "Final Allocations:"
echo "DB: ${mem_reservation_db}GB"
echo "Mangos: ${mem_reservation_mangos}GB"
echo "Realmd: ${mem_reservation_realmd}GB"

# Send to Discord if webhook is configured
if [ -n "$DISCORD_WEBHOOK" ]; then
    message="**Resource Allocation Summary:**\n"
    message+="Total Host Memory: ${TOTAL_HOST_MEMORY}GB\n"
    message+="Available (75%): ${AVAILABLE_MEMORY}GB\n\n"
    message+="**Memory Allocations:**\n"
    message+="DB: ${mem_reservation_db}GB\n"
    message+="Mangos: ${mem_reservation_mangos}GB\n"
    message+="Realmd: ${mem_reservation_realmd}GB\n\n"
    message+="**CPU Usage (Average):**\n"
    message+="DB: ${avg_cpu_db}%\n"
    message+="Mangos: ${avg_cpu_mangos}%\n"
    message+="Realmd: ${avg_cpu_realmd}%\n\n"
    message+="**CPU Shares:**\n"
    message+="DB: ${cpu_shares_db} (ratio: ${cpu_ratio_db})\n"
    message+="Mangos: ${cpu_shares_mangos} (ratio: ${cpu_ratio_mangos})\n"
    message+="Realmd: ${cpu_shares_realmd} (ratio: ${cpu_ratio_realmd})"
    
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\":\"$message\"}" \
         "$DISCORD_WEBHOOK"
fi

# Announce restart
announce_restart() {
    local initial_time=15
    local decrement=5
    local final_countdown=5

    echo "[VMaNGOS]: Starting restart announcement sequence..."

    # Loop for initial countdown intervals
    for ((time_remaining=initial_time; time_remaining > final_countdown; time_remaining-=decrement)); do
        expect <<EOF
            set timeout -1
            spawn sudo docker attach vmangos-mangos
            sleep 2
            send "announce Server Restarting in $time_remaining minutes\r"
            sleep 5
            send "\x10"
            sleep 1
            send "\x11"
            expect eof
EOF
        echo "[VMaNGOS]: Announced Server Restarting in $time_remaining minutes"
        sleep $((decrement * 60))
    done

    # Final countdown
    for ((time_remaining=final_countdown; time_remaining > 0; time_remaining--)); do
        expect <<EOF
            set timeout -1
            spawn sudo docker attach vmangos-mangos
            sleep 2
            send "announce Server Restarting in $time_remaining minutes\r"
            sleep 5
            send "\x10"
            sleep 1
            send "\x11"
            expect eof
EOF
        echo "[VMaNGOS]: Announced Server Restarting in $time_remaining minutes"
        sleep 60
    done

    # Final announcement
    expect <<EOF
        set timeout -1
        spawn sudo docker attach vmangos-mangos
        sleep 2
        send "announce Server Restarting Now!\r"
        sleep 5
        send "\x10"
        sleep 1
        send "\x11"
        expect eof
EOF
    echo "[VMaNGOS]: Announced Server Restarting Now!"
}

# Call restart function
announce_restart

# Restart services
echo "Restarting Docker Compose services..."
if ! sudo docker compose down; then
    echo "Error: Failed to bring down Docker Compose services."
    exit 1
fi

if ! sudo docker compose up -d; then
    echo "Error: Failed to bring up Docker Compose services."
    exit 1
fi

echo "Docker environment restarted with updated variables."
