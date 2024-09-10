#!/bin/bash

# Load environment variables
source .env-script

# Function to handle script call from another directory
get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

# Determine the script directory and navigate to it
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path" || { echo "[VMaNGOS]: Failed to navigate to script directory."; exit 1; }

# Define the container name
CONTAINER_NAME="vmangos-database"

# Function to execute commands inside the Docker container
exec_docker() {
  local command=$1
  docker exec -i "$CONTAINER_NAME" mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e "$command"
}

# Recreate world database
echo "[VMaNGOS]: Recreating world database..."
docker exec -i "$CONTAINER_NAME" mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS mangos; CREATE DATABASE mangos DEFAULT CHARSET utf8 COLLATE utf8_general_ci;" || { echo "[VMaNGOS]: Failed to recreate world database."; exit 1; }

# Import databases
echo "[VMaNGOS]: Importing databases…"
import_files=(
  "mangos:./vol/database-github/$VMANGOS_WORLD_DATABASE.sql"
  "mangos:./vol/core-github/sql/migrations/world_db_updates.sql"
)
for entry in "${import_files[@]}"; do
  db=$(echo $entry | cut -d: -f1)
  file=$(echo $entry | cut -d: -f2)
  echo "[VMaNGOS]: Importing $db from $file"
  docker exec -i "$CONTAINER_NAME" mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "$db" < "$file"
done

echo "[VMaNGOS]: World database recreation complete."

echo "[VMaNGOS]: Restarting environment..."
docker compose down
docker compose up -d
