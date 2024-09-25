#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables
source ./../../.env-script  # Adjusted path to environment file

# Define variables
COMPOSE_FILE="$DOCKER_DIRECTORY/docker-compose.yml"  # Adjusted path to use $DOCKER_DIRECTORY
SERVICE_NAME="vmangos-database"
ENV_FILE="$DOCKER_DIRECTORY/.env"  # Adjusted path to use $DOCKER_DIRECTORY

# Comment out MYSQL_ROOT_PASSWORD in the .env file
echo "Clearing MYSQL_ROOT_PASSWORD in the $ENV_FILE file..."
sed -i '/^MYSQL_ROOT_PASSWORD=/s/^/#/' "$ENV_FILE"

# Restart the specified service
echo "Restarting $SERVICE_NAME..."
sudo docker compose -f "$COMPOSE_FILE" stop "$SERVICE_NAME" && \
sudo docker compose -f "$COMPOSE_FILE" up -d "$SERVICE_NAME"

echo "$SERVICE_NAME has been restarted, and MYSQL_ROOT_PASSWORD is now cleared."
