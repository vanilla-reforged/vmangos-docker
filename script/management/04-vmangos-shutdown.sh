#!/bin/bash
# Simple logging function
log_message() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message"
}
# Change to the directory where the script is located
cd "$(dirname "$0")"
log_message "Shutdown script started"
# Load environment variables from .env-script
log_message "Loading environment variables"
source ./../../.env-script
# Function to shutdown the server and prevent restart
shutdown_server() {
    # Set the shutdown delay in seconds (15 minutes = 900 seconds)
    local SHUTDOWN_DELAY=900
    
    # First, update the restart policy to prevent automatic restarts
    log_message "Updating container restart policy to 'no'"
    if sudo docker update --restart=no vmangos-mangos; then
        log_message "Container restart policy updated to 'no'"
    else
        log_message "Failed to update container restart policy"
        return 1
    fi
    
    # Now initiate the server shutdown
    log_message "Initiating server shutdown (${SHUTDOWN_DELAY} second countdown)"
    
    if expect <<EOF
#!/usr/bin/expect
set timeout -1
# Start docker attach
spawn sudo docker attach vmangos-mangos
# Wait for 2 seconds to ensure the session is fully attached
sleep 2
# Send the command to shutdown the server gracefully
send "server shutdown ${SHUTDOWN_DELAY}\r"
# Wait for 5 seconds to ensure the command is processed
sleep 5
# Simulate Ctrl+P
send "\x10"
# Brief delay before simulating Ctrl+Q
sleep 1
# Simulate Ctrl+Q
send "\x11"
# End the expect script
expect eof
EOF
    then
        log_message "Server shutdown command sent successfully (${SHUTDOWN_DELAY} second countdown)"
    else
        log_message "Failed to send server shutdown command"
        return 1
    fi
    
    # Wait for the shutdown to complete (plus a small buffer)
    log_message "Waiting for server shutdown to complete..."
    sleep $((SHUTDOWN_DELAY + 10))
    
    return 0
}
# Main execution flow
if shutdown_server; then
    log_message "Server shutdown completed successfully"
    
    # Print container status
    log_message "Container status:"
    sudo docker inspect --format='{{.Name}} - Status: {{.State.Status}} - AutoRestart: {{.HostConfig.RestartPolicy.Name}}' vmangos-mangos
else
    log_message "Server shutdown process encountered errors"
fi
