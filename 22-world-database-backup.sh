#!/bin/bash

source .env

# Date and Time

timestamp=$(date +%Y%m%d_%H%M%S)

# Start

echo "[VMaNGOS]: Backing up world database..."
docker exec vmangos_database mariadb-dump -h 127.0.0.1 -u mangos -p$MYSQL_ROOT_PASSWORD --single-transaction mangos > ./vol/backup/"$timestamp"_mangos.sql

echo "[VMaNGOS]: Backup complete!"
