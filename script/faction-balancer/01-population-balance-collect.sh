#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables from .env-script
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Function to send a message to Discord (if needed for future notification)
send_discord_message() {
    local message=$1
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK"
}

# Step 1: Execute the internal script inside the container
echo "Calling internal population balance script inside the container..."
docker exec vmangos-database /01-population-balance-collect.sh

if [[ $? -eq 0 ]]; then
    echo "Population balance script executed successfully inside the container."
else
    echo "Failed to execute population balance script inside the container."
    send_discord_message "Failed to execute population balance script inside the container."
    exit 1
fi
