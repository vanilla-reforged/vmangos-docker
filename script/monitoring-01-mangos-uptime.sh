#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly ENV_SCRIPT_FILE="$PROJECT_ROOT/.env-script"
readonly CONTAINER_NAME="vmangos-mangos"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

send_discord_message() {
    local message="$1"

    if [ -z "${DISCORD_WEBHOOK:-}" ]; then
        log_message "WARNING" \
            "Discord webhook not configured, printing server information"

        printf '%s\n' "$message"
        return
    fi

    log_message "INFO" "Sending Discord notification"

    if curl -fsS \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$(jq -nc --arg content "$message" '{content: $content}')" \
        "$DISCORD_WEBHOOK" > /dev/null; then

        log_message "SUCCESS" "Discord notification sent successfully"
    else
        log_message "ERROR" "Failed to send Discord notification"
    fi
}

main() {
    local server_info
    local server_uptime
    local server_time
    local last_restart

    local days=0
    local hours=0
    local minutes=0
    local seconds=0
    local total_seconds
    local restart_timestamp

    log_message "INFO" "Script started"

    # Load optional Discord configuration
    if [ -f "$ENV_SCRIPT_FILE" ]; then
        source "$ENV_SCRIPT_FILE"
    else
        log_message "WARNING" \
            "Environment file not found: $ENV_SCRIPT_FILE"
    fi

    # Get server information
    log_message "INFO" "Getting server uptime"

    if ! server_info=$(expect <<EOF
set timeout 10
spawn sudo docker attach $CONTAINER_NAME
sleep 2
send "server info\r"
sleep 2
send "\x10"
sleep 1
send "\x11"
expect eof
EOF
    ); then
        log_message "ERROR" "Failed to get server information"
        return 1
    fi

    server_uptime=$(
        printf '%s\n' "$server_info" |
        grep -m1 "Server uptime:" |
        tr -d '\r' |
        sed 's/^[[:space:]]*//' || true
    )

    if [ -z "$server_uptime" ]; then
        log_message "ERROR" "Failed to extract server uptime"
        server_uptime="Server uptime: Unknown"
        last_restart="Unknown"
    else
        log_message "INFO" "Got server uptime: $server_uptime"

        # Extract uptime components
        if [[ "$server_uptime" =~ ([0-9]+)[[:space:]]+Day[s]? ]]; then
            days="${BASH_REMATCH[1]}"
        fi

        if [[ "$server_uptime" =~ ([0-9]+)[[:space:]]+Hour[s]? ]]; then
            hours="${BASH_REMATCH[1]}"
        fi

        if [[ "$server_uptime" =~ ([0-9]+)[[:space:]]+Minute[s]? ]]; then
            minutes="${BASH_REMATCH[1]}"
        fi

        if [[ "$server_uptime" =~ ([0-9]+)[[:space:]]+Second[s]? ]]; then
            seconds="${BASH_REMATCH[1]}"
        fi

        total_seconds=$(
            (
                days * 86400 +
                hours * 3600 +
                minutes * 60 +
                seconds
            )
        )

        restart_timestamp=$(($(date +%s) - total_seconds))
        last_restart=$(date -d "@$restart_timestamp" "+%Y-%m-%d %H:%M:%S")

        log_message "INFO" "Calculated last restart: $last_restart"
    fi

    server_time=$(date "+%Y-%m-%d %H:%M:%S")

    send_discord_message "$(
        printf '%s\nLast restart: %s\nServer time: %s' \
            "$server_uptime" \
            "$last_restart" \
            "$server_time"
    )"

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
