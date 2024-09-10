#!/bin/bash

# Load environment variables
source .env
source .env-script

# Define the container name
CONTAINER_NAME="vmangos-database"

# Function to execute commands inside the Docker container
exec_docker() {
  local command=$1
  docker exec -i "$CONTAINER_NAME" mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e "$command"
}

# Check if databases exist and abort if they do
echo "[VMaNGOS]: Checking for existing databases..."
databases=("realmd" "characters" "mangos" "logs")
for db in "${databases[@]}"; do
  if exec_docker "SHOW DATABASES LIKE '$db';" | grep -q "$db"; then
    echo "[VMaNGOS]: Database $db already exists, aborting setup."
    exit 1
  fi
done

# Create databases since none exist
echo "[VMaNGOS]: Creating databases�"
for db in "${databases[@]}"; do
  exec_docker "CREATE DATABASE IF NOT EXISTS $db DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"
done

# Create user and grant privileges
echo "[VMaNGOS]: Creating user�"
exec_docker "CREATE USER 'mangos'@'localhost' IDENTIFIED BY '$MARIADB_ROOT_PASSWORD';"
exec_docker "SET PASSWORD FOR 'mangos'@'localhost' = PASSWORD('$MARIADB_ROOT_PASSWORD');"

echo "[VMaNGOS]: Granting privileges for user�"
exec_docker "GRANT ALL PRIVILEGES ON *.* TO 'mangos'@'%' IDENTIFIED BY '$MARIADB_ROOT_PASSWORD';"
exec_docker "FLUSH PRIVILEGES;"
for db in "${databases[@]}"; do
  exec_docker "GRANT ALL ON $db.* TO 'mangos'@'localhost' WITH GRANT OPTION;"
done
exec_docker "FLUSH PRIVILEGES;"

# Import databases
echo "[VMaNGOS]: Importing databases�"
import_files=(
  "mangos:./vol/database-github/$VMANGOS_WORLD_DATABASE.sql"
  "realmd:./vol/core-github/sql/logon.sql"
  "logs:./vol/core-github/sql/logs.sql"
  "characters:./vol/core-github/sql/characters.sql"
  "mangos:./vol/core-github/sql/migrations/world_db_updates.sql"
  "characters:./vol/core-github/sql/migrations/characters_db_updates.sql"
  "realmd:./vol/core-github/sql/migrations/logon_db_updates.sql"
  "logs:./vol/core-github/sql/migrations/logs_db_updates.sql"
)
for entry in "${import_files[@]}"; do
  db=$(echo $entry | cut -d: -f1)
  file=$(echo $entry | cut -d: -f2)
  echo "[VMaNGOS]: Importing $db from $file"
  docker exec -i "$CONTAINER_NAME" mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "$db" < "$file"
done

# Upgrade MySQL
echo "[VMaNGOS]: Upgrading MySQL�"
docker exec -i "$CONTAINER_NAME" mariadb-upgrade -u root -p"$MARIADB_ROOT_PASSWORD"

# Configure default realm
echo "[VMaNGOS]: Configuring default realm�"
exec_docker "INSERT INTO realmd.realmlist (name, address, port, icon, realmflags, timezone, allowedSecurityLevel, population, gamebuild_min, gamebuild_max, flag, realmbuilds) VALUES ('$VMANGOS_REALM_NAME', '$VMANGOS_REALM_IP', '$VMANGOS_REALM_PORT', '$VMANGOS_REALM_ICON', '$VMANGOS_REALM_FLAGS', '$VMANGOS_TIMEZONE', '$VMANGOS_ALLOWED_SECURITY_LEVEL', '$VMANGOS_POPULATION', '$VMANGOS_GAMEBUILD_MIN', '$VMANGOS_GAMEBUILD_MAX', '$VMANGOS_FLAG', '');"

echo "[VMaNGOS]: Database creation complete!"