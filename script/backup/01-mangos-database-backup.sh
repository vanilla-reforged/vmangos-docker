#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Run the backup script inside the container
sudo docker exec vmangos-database /home/default/scripts/01-mangos-database-backup.sh \
  || { echo "Failed to execute backup inside container"; exit 1; }

echo "[VMaNGOS]: Backup script executed inside container!"
