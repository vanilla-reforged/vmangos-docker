#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly CONTAINER_NAME="vmangos-mangos"
readonly RESTART_POLICY="always"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

main() {
    local container_status

    log_message "INFO" "Script started"

    log_message "INFO" "Current container status"

    sudo docker inspect \
        --format='{{.Name}} - Status: {{.State.Status}} - AutoRestart: {{.HostConfig.RestartPolicy.Name}}' \
        "$CONTAINER_NAME"

    log_message "INFO" \
        "Setting restart policy to '$RESTART_POLICY'"

    sudo docker update \
        --restart="$RESTART_POLICY" \
        "$CONTAINER_NAME" > /dev/null

    log_message "SUCCESS" \
        "Container restart policy updated to '$RESTART_POLICY'"

    container_status=$(
        sudo docker inspect \
            --format='{{.State.Status}}' \
            "$CONTAINER_NAME"
    )

    if [ "$container_status" != "running" ]; then
        log_message "INFO" "Container is not running, starting it"

        sudo docker start "$CONTAINER_NAME" > /dev/null

        log_message "SUCCESS" "Container started successfully"
    else
        log_message "INFO" "Container is already running"
    fi

    log_message "INFO" "Updated container status"

    sudo docker inspect \
        --format='{{.Name}} - Status: {{.State.Status}} - AutoRestart: {{.HostConfig.RestartPolicy.Name}}' \
        "$CONTAINER_NAME"

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
