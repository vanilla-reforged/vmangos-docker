#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly ENV_SCRIPT_FILE="$PROJECT_ROOT/.env-script"
readonly ENV_FILE="$PROJECT_ROOT/.env"
readonly COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

readonly LOG_DIR="$PROJECT_ROOT/data/docker-resources"
readonly DB_LOG="$LOG_DIR/db_usage.log"
readonly MANGOS_LOG="$LOG_DIR/mangos_usage.log"
readonly REALMD_LOG="$LOG_DIR/realmd_usage.log"

readonly DATA_WINDOW_DAYS=7
readonly MEMORY_ALLOCATION_PERCENT=75

readonly MIN_RESERVATION_DB=1
readonly MIN_RESERVATION_MANGOS=1.5
readonly MIN_RESERVATION_REALMD=0.1

readonly MANGOS_CONTAINER="vmangos-mangos"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    printf '[%s] [%s] [%s] %s\n' \
        "$timestamp" \
        "$SCRIPT_NAME" \
        "$level" \
        "$message"
}

calculate_memory_average() {
    local log_file="$1"
    local threshold="$2"

    if [ ! -s "$log_file" ]; then
        printf '0\n'
        return
    fi

    awk -F',' -v threshold="$threshold" '
        $2 >= threshold {
            memory_sum += $3
            count++
        }

        END {
            if (count > 0) {
                printf "%.2f", memory_sum / count
            } else {
                print "0"
            }
        }
    ' "$log_file"
}

update_env_variable() {
    local variable_name="$1"
    local variable_value="$2"
    local temp_file

    if [ -z "$variable_value" ]; then
        log_message "WARNING" \
            "Skipping empty value for $variable_name"
        return
    fi

    temp_file=$(mktemp "${ENV_FILE}.tmp.XXXXXX")

    if grep -q "^${variable_name}=" "$ENV_FILE"; then
        sed "s|^${variable_name}=.*|${variable_name}=${variable_value}|" \
            "$ENV_FILE" > "$temp_file"
    else
        cat "$ENV_FILE" > "$temp_file"

        printf '%s=%s\n' \
            "$variable_name" \
            "$variable_value" >> "$temp_file"
    fi

    # Rewrite the existing .env file instead of replacing it.
    # This preserves ownership, permissions, and inode.
    if ! cat "$temp_file" > "$ENV_FILE"; then
        rm -f "$temp_file"

        log_message "ERROR" \
            "Failed to update $variable_name in $ENV_FILE"

        return 1
    fi

    rm -f "$temp_file"

    log_message "DEBUG" \
        "Updated $variable_name=$variable_value"
}

cleanup_log() {
    local log_file="$1"
    local threshold="$2"
    local temp_file
    local before_count
    local after_count
    local removed_count

    if [ ! -f "$log_file" ]; then
        log_message "WARNING" \
            "Log file not found, skipping cleanup: $log_file"
        return
    fi

    temp_file=$(mktemp "${log_file}.tmp.XXXXXX")
    before_count=$(wc -l < "$log_file")

    if ! awk -F',' -v threshold="$threshold" \
        '$2 >= threshold' "$log_file" > "$temp_file"; then

        rm -f "$temp_file"

        log_message "ERROR" \
            "Failed to clean log file: $log_file"

        return 1
    fi

    after_count=$(wc -l < "$temp_file")
    removed_count=$((before_count - after_count))

    # Rewrite the existing file instead of replacing it.
    # This preserves ownership, permissions, and inode.
    if ! cat "$temp_file" > "$log_file"; then
        rm -f "$temp_file"

        log_message "ERROR" \
            "Failed to rewrite log file: $log_file"

        return 1
    fi

    rm -f "$temp_file"

    if (( removed_count > 0 )); then
        log_message "INFO" \
            "Removed $removed_count old entries from ${log_file##*/}"
    fi
}

send_discord_message() {
    local message="$1"

    if [ -z "${DISCORD_WEBHOOK:-}" ]; then
        log_message "WARNING" \
            "Discord webhook not configured, skipping notification"
        return
    fi

    log_message "INFO" "Sending Discord notification"

    if curl -fsS \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$(jq -nc --arg content "$message" '{content: $content}')" \
        "$DISCORD_WEBHOOK" > /dev/null; then

        log_message "SUCCESS" \
            "Discord notification sent successfully"
    else
        log_message "ERROR" \
            "Failed to send Discord notification"
    fi
}

announce_message() {
    local message="$1"

    expect <<EOF
set timeout -1
spawn sudo docker attach $MANGOS_CONTAINER
sleep 2
send "announce $message\r"
sleep 5
send "\x10"
sleep 1
send "\x11"
expect eof
EOF
}

announce_restart() {
    local time_remaining

    log_message "INFO" \
        "Starting restart announcement sequence"

    for time_remaining in 15 10 5 4 3 2 1; do
        log_message "INFO" \
            "Announcing restart in $time_remaining minute(s)"

        if announce_message \
            "Server Restarting in $time_remaining minute(s)"; then

            log_message "SUCCESS" \
                "Restart announcement sent: $time_remaining minute(s)"
        else
            log_message "ERROR" \
                "Failed to send restart announcement: $time_remaining minute(s)"
        fi

        case "$time_remaining" in
            15|10)
                sleep 300
                ;;
            *)
                sleep 60
                ;;
        esac
    done

    log_message "INFO" \
        "Announcing immediate restart"

    if announce_message "Server Restarting Now!"; then
        log_message "SUCCESS" \
            "Final restart announcement sent"
    else
        log_message "ERROR" \
            "Failed to send final restart announcement"
    fi
}

restart_services() {
    log_message "INFO" \
        "Stopping Docker Compose services"

    if ! sudo docker compose \
        --project-directory "$PROJECT_ROOT" \
        --env-file "$ENV_FILE" \
        -f "$COMPOSE_FILE" \
        down; then

        log_message "ERROR" \
            "Failed to stop Docker Compose services"

        return 1
    fi

    log_message "SUCCESS" \
        "Docker Compose services stopped"

    log_message "INFO" \
        "Starting Docker Compose services"

    if ! sudo docker compose \
        --project-directory "$PROJECT_ROOT" \
        --env-file "$ENV_FILE" \
        -f "$COMPOSE_FILE" \
        up -d; then

        log_message "ERROR" \
            "Failed to start Docker Compose services"

        return 1
    fi

    log_message "SUCCESS" \
        "Docker Compose services started"
}

main() {
    local total_host_memory
    local available_memory
    local threshold

    local total_minimum_reservation
    local remaining_memory

    local avg_mem_db
    local avg_mem_mangos
    local avg_mem_realmd
    local total_memory_usage

    local ratio_db
    local ratio_mangos
    local ratio_realmd

    local extra_db
    local extra_mangos
    local extra_realmd

    local mem_reservation_db
    local mem_reservation_mangos
    local mem_reservation_realmd

    local memswap_limit_db
    local memswap_limit_mangos
    local memswap_limit_realmd

    local discord_message

    log_message "INFO" "Script started"

    # Validate required files and directories
    if [ ! -f "$ENV_FILE" ]; then
        log_message "ERROR" \
            "Compose environment file not found: $ENV_FILE"
        return 1
    fi

    if [ ! -f "$COMPOSE_FILE" ]; then
        log_message "ERROR" \
            "Compose file not found: $COMPOSE_FILE"
        return 1
    fi

    if [ ! -d "$LOG_DIR" ]; then
        log_message "ERROR" \
            "Resource log directory not found: $LOG_DIR"
        return 1
    fi

    # Load optional Discord configuration
    if [ -f "$ENV_SCRIPT_FILE" ]; then
        source "$ENV_SCRIPT_FILE"
    else
        log_message "WARNING" \
            "Environment file not found: $ENV_SCRIPT_FILE"
    fi

    threshold=$(date -d "$DATA_WINDOW_DAYS days ago" +%s)

    # Get total host memory in GiB
    total_host_memory=$(
        awk '/^MemTotal:/ {
            printf "%.2f", $2 / 1024 / 1024
        }' /proc/meminfo
    )

    available_memory=$(
        echo \
            "scale=2; $total_host_memory * $MEMORY_ALLOCATION_PERCENT / 100" |
        bc
    )

    log_message "INFO" \
        "Total host memory: ${total_host_memory}GB"

    log_message "INFO" \
        "Memory available for containers (${MEMORY_ALLOCATION_PERCENT}%): ${available_memory}GB"

    log_message "INFO" \
        "Using resource data from the last $DATA_WINDOW_DAYS days"

    # Calculate average memory usage
    avg_mem_db=$(
        calculate_memory_average "$DB_LOG" "$threshold"
    )

    avg_mem_mangos=$(
        calculate_memory_average "$MANGOS_LOG" "$threshold"
    )

    avg_mem_realmd=$(
        calculate_memory_average "$REALMD_LOG" "$threshold"
    )

    log_message "INFO" \
        "Average memory usage - DB: ${avg_mem_db} MiB, Mangos: ${avg_mem_mangos} MiB, Realmd: ${avg_mem_realmd} MiB"

    # Calculate minimum and remaining memory
    total_minimum_reservation=$(
        echo \
            "scale=2; $MIN_RESERVATION_DB + $MIN_RESERVATION_MANGOS + $MIN_RESERVATION_REALMD" |
        bc
    )

    remaining_memory=$(
        echo \
            "scale=2; $available_memory - $total_minimum_reservation" |
        bc
    )

    if [ "$(echo "$remaining_memory <= 0" | bc)" -eq 1 ]; then
        log_message "ERROR" \
            "Available memory is lower than the configured minimum reservations"

        discord_message=$(
            printf \
                '**Resource Allocation Failed:**\nTotal Host Memory: %sGB\nAvailable for containers (%s%%): %sGB\nMinimum reservations required: %sGB' \
                "$total_host_memory" \
                "$MEMORY_ALLOCATION_PERCENT" \
                "$available_memory" \
                "$total_minimum_reservation"
        )

        send_discord_message "$discord_message"

        return 1
    fi

    # Calculate usage ratios
    total_memory_usage=$(
        echo \
            "scale=2; $avg_mem_db + $avg_mem_mangos + $avg_mem_realmd" |
        bc
    )

    if [ "$(echo "$total_memory_usage > 0" | bc)" -eq 1 ]; then
        ratio_db=$(
            echo "scale=4; $avg_mem_db / $total_memory_usage" |
            bc
        )

        ratio_mangos=$(
            echo "scale=4; $avg_mem_mangos / $total_memory_usage" |
            bc
        )

        ratio_realmd=$(
            echo "scale=4; $avg_mem_realmd / $total_memory_usage" |
            bc
        )
    else
        ratio_db=0.25
        ratio_mangos=0.70
        ratio_realmd=0.05

        log_message "WARNING" \
            "No resource usage data available, using default memory ratios"
    fi

    # Distribute remaining memory according to usage ratios
    extra_db=$(
        echo "scale=2; $remaining_memory * $ratio_db" |
        bc
    )

    extra_mangos=$(
        echo "scale=2; $remaining_memory * $ratio_mangos" |
        bc
    )

    extra_realmd=$(
        echo "scale=2; $remaining_memory * $ratio_realmd" |
        bc
    )

    # Add minimum reservations
    mem_reservation_db=$(
        echo "scale=2; $MIN_RESERVATION_DB + $extra_db" |
        bc
    )

    mem_reservation_mangos=$(
        echo "scale=2; $MIN_RESERVATION_MANGOS + $extra_mangos" |
        bc
    )

    mem_reservation_realmd=$(
        echo "scale=2; $MIN_RESERVATION_REALMD + $extra_realmd" |
        bc
    )

    # Swap limits are twice the memory limits
    memswap_limit_db=$(
        echo "scale=2; $mem_reservation_db * 2" |
        bc
    )

    memswap_limit_mangos=$(
        echo "scale=2; $mem_reservation_mangos * 2" |
        bc
    )

    memswap_limit_realmd=$(
        echo "scale=2; $mem_reservation_realmd * 2" |
        bc
    )

    # Update Compose environment
    log_message "INFO" \
        "Updating resource allocations in $ENV_FILE"

    update_env_variable \
        "MEM_RESERVATION_DB" \
        "${mem_reservation_db}g"

    update_env_variable \
        "MEM_RESERVATION_MANGOS" \
        "${mem_reservation_mangos}g"

    update_env_variable \
        "MEM_RESERVATION_REALMD" \
        "${mem_reservation_realmd}g"

    update_env_variable \
        "MEM_LIMIT_DB" \
        "${mem_reservation_db}g"

    update_env_variable \
        "MEM_LIMIT_MANGOS" \
        "${mem_reservation_mangos}g"

    update_env_variable \
        "MEM_LIMIT_REALMD" \
        "${mem_reservation_realmd}g"

    update_env_variable \
        "MEMSWAP_LIMIT_DB" \
        "${memswap_limit_db}g"

    update_env_variable \
        "MEMSWAP_LIMIT_MANGOS" \
        "${memswap_limit_mangos}g"

    update_env_variable \
        "MEMSWAP_LIMIT_REALMD" \
        "${memswap_limit_realmd}g"

    # Clean resource logs
    log_message "INFO" "Cleaning resource logs"

    cleanup_log "$DB_LOG" "$threshold"
    cleanup_log "$MANGOS_LOG" "$threshold"
    cleanup_log "$REALMD_LOG" "$threshold"

    # Summary
    log_message "INFO" "Memory allocation summary"
    log_message "INFO" "DB: ${mem_reservation_db}GB"
    log_message "INFO" "Mangos: ${mem_reservation_mangos}GB"
    log_message "INFO" "Realmd: ${mem_reservation_realmd}GB"

    discord_message=$(
        printf \
            '**Resource Allocation Summary:**\nTotal Host Memory: %sGB\nAvailable (%s%%): %sGB\n\n**Memory Allocations:**\nDB: %sGB\nMangos: %sGB\nRealmd: %sGB' \
            "$total_host_memory" \
            "$MEMORY_ALLOCATION_PERCENT" \
            "$available_memory" \
            "$mem_reservation_db" \
            "$mem_reservation_mangos" \
            "$mem_reservation_realmd"
    )

    send_discord_message "$discord_message"

    # Announce and restart
    announce_restart
    restart_services

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
