#!/bin/bash

# Logger function for standardized logging
log_message() {
    local level="$1"
    local message="$2"
    local script_name=$(basename "$0")
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$script_name] [$level] $message"
}

# Change to the directory where the script is located
cd "$(dirname "$0")"
log_message "INFO" "Script started"

# Load environment variables from .env-script
log_message "INFO" "Loading environment variables"
source ./../../.env-script

# Get total host memory and calculate 75% available memory
TOTAL_HOST_MEMORY=$(free -g | awk '/^Mem:/{print $2}')
AVAILABLE_MEMORY=$(echo "scale=2; $TOTAL_HOST_MEMORY * 0.75" | bc)
log_message "INFO" "Total host memory: ${TOTAL_HOST_MEMORY}GB, Available memory (75%): ${AVAILABLE_MEMORY}GB"

# Directories for logs
LOG_DIR="$DOCKER_DIRECTORY/vol/docker-resources"
DB_LOG="$LOG_DIR/db_usage.log"
MANGOS_LOG="$LOG_DIR/mangos_usage.log"
REALMD_LOG="$LOG_DIR/realmd_usage.log"

log_message "DEBUG" "Log Files - DB: $DB_LOG, Mangos: $MANGOS_LOG, Realmd: $REALMD_LOG"

# Time threshold (7 days ago in seconds)
SEVEN_DAYS_AGO=$(date -d '7 days ago' +%s)
log_message "INFO" "Using data from the last 7 days (since $(date -d @$SEVEN_DAYS_AGO '+%Y-%m-%d %H:%M:%S'))"

# Define minimum reservations in gigabytes
MIN_RESERVATION_DB=1 # 1 GB
MIN_RESERVATION_MANGOS=1.5  # 1.5 GB
MIN_RESERVATION_REALMD=0.1 # 100 MB
log_message "INFO" "Minimum reservations - DB: ${MIN_RESERVATION_DB}GB, Mangos: ${MIN_RESERVATION_MANGOS}GB, Realmd: ${MIN_RESERVATION_REALMD}GB"

# Calculate total minimum reservations
TOTAL_MIN_RESERVATION=$(echo "scale=2; $MIN_RESERVATION_DB + $MIN_RESERVATION_MANGOS + $MIN_RESERVATION_REALMD" | bc)

# Calculate remaining memory after minimums
REMAINING_MEMORY=$(echo "scale=2; $AVAILABLE_MEMORY - $TOTAL_MIN_RESERVATION" | bc)
log_message "INFO" "Total minimum reservation: ${TOTAL_MIN_RESERVATION}GB, Remaining memory for distribution: ${REMAINING_MEMORY}GB"

# Function to calculate average usage, including all values
calculate_average() {
    local log_file=$1
    if [ ! -f "$log_file" ] || [ ! -s "$log_file" ]; then
        log_message "WARNING" "Log file $log_file doesn't exist or is empty, returning zeros"
        echo "0,0"
        return
    fi

    # Use awk to process the log file, including all values within the time period
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
log_message "INFO" "Calculating averages from logs"
avg_db=$(calculate_average "$DB_LOG")
avg_mangos=$(calculate_average "$MANGOS_LOG")
avg_realmd=$(calculate_average "$REALMD_LOG")

# Extract memory values with validation
avg_mem_db=$(echo "$avg_db" | cut -d',' -f2 | grep -E '^[0-9]*\.?[0-9]+$' || echo "0")
avg_mem_mangos=$(echo "$avg_mangos" | cut -d',' -f2 | grep -E '^[0-9]*\.?[0-9]+$' || echo "0")
avg_mem_realmd=$(echo "$avg_realmd" | cut -d',' -f2 | grep -E '^[0-9]*\.?[0-9]+$' || echo "0")

log_message "DEBUG" "Raw Memory Values - DB: $avg_mem_db MB, Mangos: $avg_mem_mangos MB, Realmd: $avg_mem_realmd MB"

# Calculate total memory usage for ratio calculation
total_mem_usage=$(echo "scale=2; $avg_mem_db + $avg_mem_mangos + $avg_mem_realmd" | bc)

log_message "INFO" "Total Memory Usage: $total_mem_usage MB"

# Calculate ratios
if [ "$(echo "$total_mem_usage > 0" | bc)" -eq 1 ]; then
    ratio_db=$(echo "scale=4; $avg_mem_db / $total_mem_usage" | bc)
    ratio_mangos=$(echo "scale=4; $avg_mem_mangos / $total_mem_usage" | bc)
    ratio_realmd=$(echo "scale=4; $avg_mem_realmd / $total_mem_usage" | bc)
    log_message "INFO" "Calculated ratios from logs"
else
    # Default ratios if no usage data
    ratio_db=0.25
    ratio_mangos=0.70
    ratio_realmd=0.05
    log_message "WARNING" "Using default ratios due to zero total memory usage"
fi

log_message "DEBUG" "Memory Ratios - DB: $ratio_db, Mangos: $ratio_mangos, Realmd: $ratio_realmd"

# Distribute remaining memory according to ratios
extra_db=$(echo "scale=2; $REMAINING_MEMORY * $ratio_db" | bc)
extra_mangos=$(echo "scale=2; $REMAINING_MEMORY * $ratio_mangos" | bc)
extra_realmd=$(echo "scale=2; $REMAINING_MEMORY * $ratio_realmd" | bc)

log_message "DEBUG" "Extra Memory - DB: $extra_db GB, Mangos: $extra_mangos GB, Realmd: $extra_realmd GB"

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
log_message "INFO" "Average CPU Usage - DB: $avg_cpu_db%, Mangos: $avg_cpu_mangos%, Realmd: $avg_cpu_realmd%, Total: $total_cpu%"

# Calculate CPU shares based on usage
BASE_CPU_SHARES=1024  # Default Docker CPU shares
MAX_MULTIPLIER=30     # Maximum multiplier for shares

if [ "$(echo "$total_cpu > 0" | bc)" -eq 1 ]; then
    cpu_ratio_db=$(echo "scale=4; $avg_cpu_db / $total_cpu" | bc)
    cpu_ratio_mangos=$(echo "scale=4; $avg_cpu_mangos / $total_cpu" | bc)
    cpu_ratio_realmd=$(echo "scale=4; $avg_cpu_realmd / $total_cpu" | bc)
    
    # Calculate shares with new formula and force integer values:
    # BASE_CPU_SHARES + (ratio * (MAX_MULTIPLIER-1) * BASE_CPU_SHARES)
    cpu_shares_db=$(echo "$BASE_CPU_SHARES + ($cpu_ratio_db * ($MAX_MULTIPLIER - 1) * $BASE_CPU_SHARES)" | awk '{printf "%d", $0}')
    cpu_shares_mangos=$(echo "$BASE_CPU_SHARES + ($cpu_ratio_mangos * ($MAX_MULTIPLIER - 1) * $BASE_CPU_SHARES)" | awk '{printf "%d", $0}')
    cpu_shares_realmd=$(echo "$BASE_CPU_SHARES + ($cpu_ratio_realmd * ($MAX_MULTIPLIER - 1) * $BASE_CPU_SHARES)" | awk '{printf "%d", $0}')
    log_message "INFO" "Calculated CPU shares based on usage ratios"
else
    # If no CPU usage data, use default shares
    cpu_shares_db=$BASE_CPU_SHARES
    cpu_shares_mangos=$BASE_CPU_SHARES
    cpu_shares_realmd=$BASE_CPU_SHARES
    log_message "WARNING" "No CPU usage data, using default CPU shares"
fi

# Ensure all CPU shares are integers
cpu_shares_db=${cpu_shares_db%.*}
cpu_shares_mangos=${cpu_shares_mangos%.*}
cpu_shares_realmd=${cpu_shares_realmd%.*}

# Function to update or add a variable in the .env file
update_env_variable() {
    var_name=$1
    var_value=$2
    env_file="./../../.env"
    
    if [ -z "$var_value" ]; then
        log_message "WARNING" "Skipping update of $var_name as value is empty"
        return
    fi

    if grep -q "^${var_name}=" "$env_file"; then
        sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" "$env_file"
    else
        echo "${var_name}=${var_value}" >> "$env_file"
    fi
    log_message "DEBUG" "Updated $var_name=$var_value in .env file"
}

# Ensure the .env file exists
touch ./../../.env
log_message "INFO" "Updating resource allocations in .env file"

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
        log_message "INFO" "Cleaning up old entries from $log_file"
        awk -F',' -v threshold=$SEVEN_DAYS_AGO '$1 >= threshold' "$log_file" > "${log_file}.tmp" && mv "${log_file}.tmp" "$log_file"
    else
        log_message "WARNING" "Log file $log_file not found, skipping cleanup"
    fi
}

log_message "INFO" "Cleaning up old log entries"
cleanup_log "$DB_LOG"
cleanup_log "$MANGOS_LOG"
cleanup_log "$REALMD_LOG"

# Print summary
log_message "INFO" "Memory Allocation Summary"
log_message "INFO" "Total Host Memory: ${TOTAL_HOST_MEMORY}GB"
log_message "INFO" "Available Memory (75%): ${AVAILABLE_MEMORY}GB"
log_message "INFO" "Total Minimum Reservation: ${TOTAL_MIN_RESERVATION}GB"
log_message "INFO" "Remaining for Distribution: ${REMAINING_MEMORY}GB"
log_message "INFO" "Usage Ratios (DB:Mangos:Realmd): ${ratio_db}:${ratio_mangos}:${ratio_realmd}"
log_message "INFO" "Final Allocations - DB: ${mem_reservation_db}GB, Mangos: ${mem_reservation_mangos}GB, Realmd: ${mem_reservation_realmd}GB"

# Send to Discord if webhook is configured
if [ -n "$DISCORD_WEBHOOK" ]; then
    log_message "INFO" "Sending resource allocation summary to Discord"
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
    
    if curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\":\"$message\"}" \
         "$DISCORD_WEBHOOK"; then
        log_message "SUCCESS" "Discord notification sent successfully"
    else
        log_message "ERROR" "Failed to send Discord notification"
    fi
else
    log_message "WARNING" "Discord webhook not configured, skipping notification"
fi

# Announce restart
announce_restart() {
    local initial_time=15
    local decrement=5
    local final_countdown=5

    log_message "INFO" "Starting restart announcement sequence"

    # Loop for initial countdown intervals
    for ((time_remaining=initial_time; time_remaining > final_countdown; time_remaining-=decrement)); do
        log_message "INFO" "Announcing restart in $time_remaining minutes"
        if expect <<EOF
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
        then
            log_message "SUCCESS" "Announced server restarting in $time_remaining minutes"
        else
            log_message "ERROR" "Failed to announce restart countdown ($time_remaining minutes)"
        fi
        sleep $((decrement * 60))
    done

    # Final countdown
    for ((time_remaining=final_countdown; time_remaining > 0; time_remaining--)); do
        log_message "INFO" "Announcing restart in $time_remaining minutes"
        if expect <<EOF
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
        then
            log_message "SUCCESS" "Announced server restarting in $time_remaining minutes"
        else
            log_message "ERROR" "Failed to announce restart countdown ($time_remaining minutes)"
        fi
        sleep 60
    done

    # Final announcement
    log_message "INFO" "Announcing final restart"
    if expect <<EOF
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
    then
        log_message "SUCCESS" "Announced server restarting now"
    else
        log_message "ERROR" "Failed to announce final restart"
    fi
}

# Call restart function
log_message "INFO" "Starting server restart announcement sequence"
announce_restart

# Restart services
log_message "INFO" "Restarting Docker Compose services"
if sudo docker compose down; then
    log_message "SUCCESS" "Successfully stopped Docker Compose services"
else
    log_message "ERROR" "Failed to bring down Docker Compose services"
    exit 1
fi

if sudo docker compose up -d; then
    log_message "SUCCESS" "Successfully started Docker Compose services"
else
    log_message "ERROR" "Failed to bring up Docker Compose services"
    exit 1
fi

log_message "SUCCESS" "Docker environment restarted with updated variables"
