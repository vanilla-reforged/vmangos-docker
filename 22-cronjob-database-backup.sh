#!/bin/bash

#Get variables defined in .env

source .env

#Date and Time Variable

date_time=$(date "+%Y.%m.%d_%H.%M.%S")

#Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

# Start

echo "[VMaNGOS]: Backing up databases..."
docker exec vmangos_database /bin/bash 'mariadb-dump -h 127.0.0.1 -u root -p$MYSQL_ROOT_PASSWORD --single-transaction characters > /backup/"$date_time"_characters.sql'
docker exec vmangos_database /bin/bash 'mariadb-dump -h 127.0.0.1 -u root -p$MYSQL_ROOT_PASSWORD --single-transaction realmd > /backup/"$date_time"_realmd.sql'
docker exec vmangos_database /bin/bash 'mariadb-dump -h 127.0.0.1 -u root -p$MYSQL_ROOT_PASSWORD --single-transaction logs > /backup/"$date_time"_logs.sql'

echo "[VMaNGOS]: Backup complete!"
