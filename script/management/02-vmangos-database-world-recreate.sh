#!/bin/bash

# Load environment variables
source ./../../.env-script  # Adjusted to load .env-script from the project root using $DOCKER_DIRECTORY

# Define the container name
CONTAINER_NAME="vmangos-database"

# Function to execute commands inside the Docker container
exec_docker() {
  local command=$1
  sudo docker exec -i "$CONTAINER_NAME" mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "$command"
}

# Recreate world database
echo "[VMaNGOS]: Recreating world database..."
sudo docker exec -i "$CONTAINER_NAME" mariadb -u root -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS mangos; CREATE DATABASE mangos DEFAULT CHARSET utf8 COLLATE utf8_general_ci;" || { echo "[VMaNGOS]: Failed to recreate world database."; exit 1; }

# Import databases
echo "[VMaNGOS]: Importing databases…"
import_files=(
  "mangos:$DOCKER_DIRECTORY/vol/database-github/$VMANGOS_WORLD_DATABASE.sql"
  "mangos:$DOCKER_DIRECTORY/vol/core-github/sql/migrations/world_db_updates.sql"
)
for entry in "${import_files[@]}"; do
  db=$(echo $entry | cut -d: -f1)
  file=$(echo $entry | cut -d: -f2)
  echo "[VMaNGOS]: Importing $db from $file"
  sudo docker exec -i "$CONTAINER_NAME" mariadb -u root -p"$MYSQL_ROOT_PASSWORD" "$db" < "$file"
done

echo "[VMaNGOS]: World database recreation complete."

echo "[VMaNGOS]: Restarting environment..."
sudo docker compose down
sudo docker compose up -d
