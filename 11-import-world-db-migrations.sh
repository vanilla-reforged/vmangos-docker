#!/bin/bash

# Get variables defined in .env-script
source .env-script

# Handle script call from other directory
get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

# Start
echo "[VMaNGOS]: Importing migrations…"
docker exec -i vmangos-database mariadb -u root -p$MARIADB_ROOT_PASSWORD mangos < ./vol/core-github/sql/migrations/world_db_updates.sql

echo "[VMaNGOS]: Restarting environment..."
docker compose down
docker compose up -d