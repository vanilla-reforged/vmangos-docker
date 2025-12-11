#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Get variables defined in .env-script
source ./../../.env-script  # Adjusted to correctly load .env-script from the project root using $DOCKER_DIRECTORY

# Start
echo "[VMaNGOS]: Importing migrations…"
docker exec -i vmangos-database mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < "$DOCKER_DIRECTORY/vol/core-github/sql/migrations/world_db_updates.sql"
docker exec -i vmangos-database mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < "$DOCKER_DIRECTORY/vol/core-github/sql/migrations/characters_db_updates.sql"
docker exec -i vmangos-database mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < "$DOCKER_DIRECTORY/vol/core-github/sql/migrations/logon_db_updates.sql"
docker exec -i vmangos-database mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < "$DOCKER_DIRECTORY/vol/core-github/sql/migrations/logs_db_updates.sql"


echo "[VMaNGOS]: Restarting environment..."
docker compose down
docker compose up -d
