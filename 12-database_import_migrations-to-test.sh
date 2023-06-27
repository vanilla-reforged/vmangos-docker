#!/bin/bash

#Get variables defined in .env

source .env

#Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

docker exec -T vmangos_database bin/sh -c \
  '[ -e /opt/core/sql/migrations/world_db_updates.sql ] mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos < /src/github_core/sql/migrations/world_db_updates.sql'
docker exec -T vmangos_database sh -c \
  '[ -e /opt/core/sql/migrations/characters_db_updates.sql ] mariadb -u mangos -p$MYSQL_ROOT_PASSWORD characters < /src/github_core/sql/migrations/characters_db_updates.sql'
docker exec -T vmangos_database sh -c \ 'mariadb-dump -h 127.0.0.1 -u root -p$MYSQL_ROOT_PASSWORD realmd > /backup/"$date_time"_realmd.sql'

docker exec -T vmangos_database sh -c

echo "[VMaNGOS]: Importing database updates..."


[ -e /opt/core/sql/migrations/logon_db_updates.sql ] mariadb -u mangos -p$MYSQL_ROOT_PASSWORD realmd < /src/github_core/sql/migrations/logon_db_updates.sql
[ -e /opt/core/sql/migrations/logs_db_updates.sql ] mariadb -u mangos -p$MYSQL_ROOT_PASSWORD logs < /src/github_core/sql/migrations/logs_db_updates.sql
