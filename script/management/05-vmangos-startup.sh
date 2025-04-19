#!/bin/bash

# Simple logging function
log_message() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message"
}

# Change to the directory where the script is located
cd "$(dirname "$0")"
log_message "Enable restart script started"

# Load environment variables from .env-script if needed
source ./../../.env-script

# Function to enable automatic restart for the container and start it if needed
enable_restart() {
    local CONTAINER_NAME="vmangos-mangos"
    local RESTART_POLICY="always"
    
    log_message "Enabling automatic restart for container $CONTAINER_NAME"
    
    # Get current container status before change
    log_message "Current container status:"
    sudo docker inspect --format='{{.Name}} - Status: {{.State.Status}} - AutoRestart: {{.HostConfig.RestartPolicy.Name}}' $CONTAINER_NAME
    
    # Update the container restart policy
    if sudo docker update --restart=$RESTART_POLICY $CONTAINER_NAME; then
        log_message "Container restart policy updated to '$RESTART_POLICY'"
        
        # Check if the container is running
        if [[ $(sudo docker inspect --format='{{.State.Status}}' $CONTAINER_NAME) != "running" ]]; then
            log_message "Container is not running. Starting it now..."
            if sudo docker start $CONTAINER_NAME; then
                log_message "Container started successfully"
            else
                log_message "Failed to start container"
                return 1
            fi
        else
            log_message "Container is already running"
        fi
        
        # Get new container status after change
        log_message "New container status:"
        sudo docker inspect --format='{{.Name}} - Status: {{.State.Status}} - AutoRestart: {{.HostConfig.RestartPolicy.Name}}' $CONTAINER_NAME
        return 0
    else
        log_message "Failed to update container restart policy"
        return 1
    fi
}

# Main execution
if enable_restart; then
    log_message "Container automatic restart enabled successfully"
else
    log_message "Failed to enable container automatic restart"
fi
