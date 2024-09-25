#!/bin/bash

# Get variables defined in .env-script
source ./../../.env-script  # Adjusted to correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Start
echo "[VMaNGOS]: Importing migrations…"
sudo docker exec -i vmangos-database mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < "$DOCKER_DIRECTORY/vol/core-github/sql/migrations/world_db_updates.sql"  # Adjusted path to use $DOCKER_DIRECTORY

echo "[VMaNGOS]: Restarting environment..."
sudo docker compose down
sudo docker compose up -d
