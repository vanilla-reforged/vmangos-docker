#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly ENV_SCRIPT_FILE="$PROJECT_ROOT/.env-script"

readonly CONTAINER_NAME="vmangos-database"
readonly CONTAINER_SCRIPT="/home/default/scripts/01-population-balance-collect.sh"

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

        log_message "SUCCESS" "Discord notification sent successfully"
    else
        log_message "ERROR" "Failed to send Discord notification"
    fi
}

main() {
    log_message "INFO" "Script started"

    # Load optional notification configuration
    if [ -f "$ENV_SCRIPT_FILE" ]; then
        source "$ENV_SCRIPT_FILE"
    else
        log_message "WARNING" \
            "Environment file not found: $ENV_SCRIPT_FILE"
    fi

    log_message "INFO" "Collecting population balance data"

    if ! sudo docker exec "$CONTAINER_NAME" "$CONTAINER_SCRIPT"; then
        log_message "ERROR" "Population balance collection failed"

        send_discord_message \
            "Failed to collect population balance data."

        return 1
    fi

    log_message "SUCCESS" "Population balance data collected successfully"
    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
