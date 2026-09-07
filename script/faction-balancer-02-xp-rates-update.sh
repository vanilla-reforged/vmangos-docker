#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly ENV_SCRIPT_FILE="$PROJECT_ROOT/.env-script"

readonly POPULATION_DATA_FILE="$PROJECT_ROOT/vol/faction-balancer/population_data.csv"
readonly CONFIG_FILE="$PROJECT_ROOT/vol/configuration/mangosd.conf"

readonly DATA_WINDOW_DAYS=7
readonly MANGOS_CONTAINER="vmangos-mangos"

readonly RESTART_DELAY=900
readonly RESTART_BUFFER=10

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

calculate_population_averages() {
    local cutoff_date="$1"

    awk -F',' -v cutoff="$cutoff_date" '
        $1 >= cutoff {
            alliance_total += $2
            horde_total += $3
            count++
        }

        END {
            if (count > 0) {
                printf "%.2f,%.2f\n",
                    alliance_total / count,
                    horde_total / count
            } else {
                print "0.00,0.00"
            }
        }
    ' "$POPULATION_DATA_FILE"
}

update_xp_rates() {
    local alliance_rate="$1"
    local horde_rate="$2"
    local temp_file

    temp_file=$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")

    if ! sed \
        -e "s/^Rate\.XP\.Kill\.Alliance = .*/Rate.XP.Kill.Alliance = $alliance_rate/" \
        -e "s/^Rate\.XP\.Kill\.Elite\.Alliance = .*/Rate.XP.Kill.Elite.Alliance = $alliance_rate/" \
        -e "s/^Rate\.XP\.Kill\.Horde = .*/Rate.XP.Kill.Horde = $horde_rate/" \
        -e "s/^Rate\.XP\.Kill\.Elite\.Horde = .*/Rate.XP.Kill.Elite.Horde = $horde_rate/" \
        "$CONFIG_FILE" > "$temp_file"; then

        rm -f "$temp_file"

        log_message "ERROR" \
            "Failed to prepare configuration update"

        return 1
    fi

    # Rewrite the existing file instead of replacing it.
    # This preserves ownership, permissions, and inode.
    if ! cat "$temp_file" > "$CONFIG_FILE"; then
        rm -f "$temp_file"

        log_message "ERROR" \
            "Failed to update configuration file"

        return 1
    fi

    rm -f "$temp_file"

    log_message "SUCCESS" \
        "XP rates updated: Alliance=$alliance_rate, Horde=$horde_rate"
}

cleanup_population_data() {
    local cutoff_date="$1"
    local temp_file
    local before_count
    local after_count
    local removed_count

    if [ ! -f "$POPULATION_DATA_FILE" ]; then
        log_message "WARNING" \
            "Population data file not found, skipping cleanup"
        return
    fi

    temp_file=$(mktemp "${POPULATION_DATA_FILE}.tmp.XXXXXX")
    before_count=$(wc -l < "$POPULATION_DATA_FILE")

    if ! awk -F',' -v cutoff="$cutoff_date" \
        '$1 >= cutoff' "$POPULATION_DATA_FILE" > "$temp_file"; then

        rm -f "$temp_file"

        log_message "ERROR" \
            "Failed to clean population data"

        return 1
    fi

    after_count=$(wc -l < "$temp_file")
    removed_count=$((before_count - after_count))

    # Rewrite the existing file instead of replacing it.
    # This preserves ownership, permissions, and inode.
    if ! cat "$temp_file" > "$POPULATION_DATA_FILE"; then
        rm -f "$temp_file"

        log_message "ERROR" \
            "Failed to update population data file"

        return 1
    fi

    rm -f "$temp_file"

    log_message "SUCCESS" \
        "Population data cleaned up: $removed_count old entrie(s) removed"
}

restart_server() {
    log_message "INFO" \
        "Scheduling server restart with a $RESTART_DELAY second countdown"

    if expect <<EOF
set timeout -1
spawn sudo docker attach $MANGOS_CONTAINER
sleep 2
send "server restart $RESTART_DELAY\r"
sleep 5
send "\x10"
sleep 1
send "\x11"
expect eof
EOF
    then
        log_message "SUCCESS" \
            "Server restart scheduled successfully"
    else
        log_message "ERROR" \
            "Failed to schedule server restart"

        return 1
    fi
}

wait_for_restart() {
    log_message "INFO" \
        "Waiting for server restart to complete"

    sleep $((RESTART_DELAY + RESTART_BUFFER))

    if sudo docker container inspect \
        --format '{{.State.Running}}' \
        "$MANGOS_CONTAINER" 2>/dev/null |
        grep -qx 'true'; then

        log_message "SUCCESS" \
            "VMaNGOS container is running after restart"

        return
    fi

    log_message "ERROR" \
        "VMaNGOS container is not running after restart"

    return 1
}

main() {
    local cutoff_date
    local alliance_avg
    local horde_avg
    local total_avg
    local alliance_percent
    local horde_percent

    local alliance_rate
    local horde_rate
    local update_message
    local discord_message

    log_message "INFO" "Script started"

    # Load optional Discord configuration
    if [ -f "$ENV_SCRIPT_FILE" ]; then
        source "$ENV_SCRIPT_FILE"
    else
        log_message "WARNING" \
            "Environment file not found: $ENV_SCRIPT_FILE"
    fi

    # Validate required files
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERROR" \
            "Configuration file not found: $CONFIG_FILE"

        return 1
    fi

    cutoff_date=$(
        date -d "$DATA_WINDOW_DAYS days ago" \
            "+%Y-%m-%d %H:%M:%S"
    )

    log_message "INFO" \
        "Analyzing population data from the last $DATA_WINDOW_DAYS days"

    if [ -f "$POPULATION_DATA_FILE" ]; then
        IFS=',' read -r alliance_avg horde_avg < <(
            calculate_population_averages "$cutoff_date"
        )
    else
        log_message "WARNING" \
            "Population data file not found, using zero population"

        alliance_avg="0.00"
        horde_avg="0.00"
    fi

    log_message "INFO" \
        "Average population - Alliance: $alliance_avg, Horde: $horde_avg"

    total_avg=$(
        awk -v alliance="$alliance_avg" -v horde="$horde_avg" \
            'BEGIN { printf "%.2f", alliance + horde }'
    )

    if awk -v total="$total_avg" \
        'BEGIN { exit !(total > 0) }'; then

        alliance_percent=$(
            awk -v alliance="$alliance_avg" -v total="$total_avg" \
                'BEGIN { printf "%.2f", alliance / total * 100 }'
        )

        horde_percent=$(
            awk -v horde="$horde_avg" -v total="$total_avg" \
                'BEGIN { printf "%.2f", horde / total * 100 }'
        )
    else
        alliance_percent="50.00"
        horde_percent="50.00"

        log_message "WARNING" \
            "No population data available, treating factions as balanced"
    fi

    log_message "INFO" \
        "Population balance - Alliance: ${alliance_percent}%, Horde: ${horde_percent}%"

    if awk -v alliance="$alliance_percent" \
        'BEGIN { exit !(alliance > 55) }'; then

        alliance_rate=1
        horde_rate=2

        update_message="Alliance is overpopulated. Setting Alliance XP rate to 1 and Horde XP rate to 2."

        log_message "INFO" \
            "Alliance is overpopulated"

    elif awk -v horde="$horde_percent" \
        'BEGIN { exit !(horde > 55) }'; then

        alliance_rate=2
        horde_rate=1

        update_message="Horde is overpopulated. Setting Horde XP rate to 1 and Alliance XP rate to 2."

        log_message "INFO" \
            "Horde is overpopulated"

    else
        alliance_rate=1
        horde_rate=1

        update_message="Populations are balanced. Setting both faction XP rates to 1."

        log_message "INFO" \
            "Population is balanced"
    fi

    update_xp_rates \
        "$alliance_rate" \
        "$horde_rate"

    log_message "INFO" \
        "Cleaning old population data"

    cleanup_population_data "$cutoff_date"

    discord_message=$(
        printf \
            '**Faction Balance Update:**\nAlliance: %s%%\nHorde: %s%%\n\n%s\n\n**VMaNGOS will restart in 15 minutes to apply the updated configuration.**' \
            "$alliance_percent" \
            "$horde_percent" \
            "$update_message"
    )

    send_discord_message "$discord_message"

    if ! restart_server; then
        send_discord_message \
            "**Faction Balance Update Failed:** Unable to schedule the VMaNGOS restart."

        return 1
    fi

    if ! wait_for_restart; then
        send_discord_message \
            "**VMaNGOS Restart Failed:** The VMaNGOS container is not running after the scheduled restart."

        return 1
    fi

    send_discord_message \
        "**VMaNGOS Restart Completed:** The faction balance configuration was applied and the VMaNGOS container is running."

    log_message "SUCCESS" \
        "Script completed successfully"
}

main "$@"
