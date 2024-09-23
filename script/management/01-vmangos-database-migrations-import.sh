#!/bin/bash

# Get variables defined in .env-script
source .env-script

# Start
echo "[VMaNGOS]: Importing migrations�"
docker exec -i vmangos-database mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < ./vol/core-github/sql/migrations/world_db_updates.sql

echo "[VMaNGOS]: Restarting environment..."
docker compose down
docker compose up -d