#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly ENV_SCRIPT_FILE="$PROJECT_ROOT/.env-script"

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
            "Discord webhook not configured, printing disk information"

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
    local filesystem
    local size
    local used
    local available
    local use_percent
    local server_time
    local discord_message

    log_message "INFO" "Script started"

    # Load optional Discord configuration
    if [ -f "$ENV_SCRIPT_FILE" ]; then
        source "$ENV_SCRIPT_FILE"
    else
        log_message "WARNING" \
            "Environment file not found: $ENV_SCRIPT_FILE"
    fi

    # Get disk space information for the root filesystem
    log_message "INFO" "Getting disk space information"

    read -r filesystem size used available use_percent < <(
        df -hP / |
        awk 'NR == 2 { print $1, $2, $3, $4, $5 }'
    )

    log_message "INFO" \
        "Disk usage - Size: $size, Used: $used, Available: $available, Use: $use_percent"

    server_time=$(date "+%Y-%m-%d %H:%M:%S")

    discord_message=$(
        printf \
            '**Docker Host Disk Space Report**\n**Filesystem:** %s\n**Total Size:** %s\n**Used:** %s (%s)\n**Available:** %s\n**Server Time:** %s' \
            "$filesystem" \
            "$size" \
            "$used" \
            "$use_percent" \
            "$available" \
            "$server_time"
    )

    send_discord_message "$discord_message"

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
