#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly CONTAINER_NAME="vmangos-mangos"
readonly SHUTDOWN_DELAY=900

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

shutdown_server() {
    # Prevent Docker from automatically restarting the container
    log_message "INFO" "Disabling automatic container restart"

    if ! sudo docker update --restart=no "$CONTAINER_NAME" > /dev/null; then
        log_message "ERROR" "Failed to disable automatic container restart"
        return 1
    fi

    log_message "SUCCESS" "Automatic container restart disabled"

    # Initiate graceful server shutdown
    log_message "INFO" \
        "Initiating server shutdown with a $SHUTDOWN_DELAY second countdown"

    if ! expect <<EOF
set timeout -1
spawn sudo docker attach $CONTAINER_NAME
sleep 2
send "server shutdown $SHUTDOWN_DELAY\r"
sleep 5
send "\x10"
sleep 1
send "\x11"
expect eof
EOF
    then
        log_message "ERROR" "Failed to send server shutdown command"
        return 1
    fi

    log_message "SUCCESS" \
        "Server shutdown command sent successfully"

    # Wait for the shutdown countdown plus a small buffer
    log_message "INFO" "Waiting for server shutdown to complete"

    sleep $((SHUTDOWN_DELAY + 10))
}

main() {
    log_message "INFO" "Script started"

    if ! shutdown_server; then
        log_message "ERROR" "Server shutdown failed"
        return 1
    fi

    log_message "SUCCESS" "Server shutdown completed successfully"

    log_message "INFO" "Container status"

    sudo docker inspect \
        --format='{{.Name}} - Status: {{.State.Status}} - AutoRestart: {{.HostConfig.RestartPolicy.Name}}' \
        "$CONTAINER_NAME"

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
