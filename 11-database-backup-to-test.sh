#!/bin/bash

#Get variables defined in .env

source .env

#Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

date_time=$(date "+%Y.%m.%d-%H.%M.%S")

echo "[VMaNGOS]: Backing up databases..."

docker exec vmangos_database /bin/sh \
  'mariadb-dump -h 127.0.0.1 -u root -p$MYSQL_ROOT_PASSWORD mangos > /backup/"$date_time"_mangos.sql'
docker exec vmangos_database /bin/sh \
  'mariadb-dump -h 127.0.0.1 -u root -p$MYSQL_ROOT_PASSWORD characters > /backup/"$date_time"_characters.sql'
docker exec vmangos_database /bin/sh \
  'mariadb-dump -h 127.0.0.1 -u root -p$MYSQL_ROOT_PASSWORD realmd > /backup/"$date_time"_realmd.sql'

echo "[VMaNGOS]: Backup complete!"
