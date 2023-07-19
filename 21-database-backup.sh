#!/bin/bash

source .env

# Date and Time

timestamp=$(date +%Y%m%d_%H%M%S)

# Start

echo "[VMaNGOS]: Backing up databases..."
docker exec vmangos_database mariadb-dump -h 127.0.0.1 -u mangos -p$MYSQL_ROOT_PASSWORD --single-transaction characters > ./vol/backup/"$timestamp"_characters.sql
docker exec vmangos_database mariadb-dump -h 127.0.0.1 -u mangos -p$MYSQL_ROOT_PASSWORD --single-transaction realmd > ./vol/backup/"$timestamp"_realmd.sql
docker exec vmangos_database mariadb-dump -h 127.0.0.1 -u mangos -p$MYSQL_ROOT_PASSWORD --single-transaction logs > ./vol/backup/"$timestamp"_logs.sql

echo "[VMaNGOS]: Backup complete!"
