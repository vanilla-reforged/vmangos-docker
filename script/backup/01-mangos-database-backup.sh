#!/bin/bash

# Load environment variables from .env-script
source ./../../.env-script  # Correctly loads the .env-script file, which defines $DOCKER_DIRECTORY

# Define variables
CONTAINER_NAME="vmangos-database"
BACKUP_DIR="/vol/backup"  # This is the directory inside the container
HOST_BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"  # Define the directory on the host where backups will be stored
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATABASE="mangos"

# Ensure the host backup directory exists
if [ ! -d "$HOST_BACKUP_DIR" ]; then
  echo "[VMaNGOS]: Creating host backup directory at $HOST_BACKUP_DIR..."
  mkdir -p "$HOST_BACKUP_DIR"
  chmod 755 "$HOST_BACKUP_DIR"
fi

# Function to back up a database
backup_database() {
  local db_name=$1
  echo "[VMaNGOS]: Backing up $db_name database..."
  sudo docker exec "$CONTAINER_NAME" mariadb-dump -h 127.0.0.1 -u mangos -p"$MYSQL_ROOT_PASSWORD" --single-transaction "$db_name" > "$HOST_BACKUP_DIR/${db_name}_${TIMESTAMP}.sql" \
    || { echo "Failed to back up $db_name"; exit 1; }
}

# Backup the database
backup_database "$DATABASE"

echo "[VMaNGOS]: Backup complete!"
