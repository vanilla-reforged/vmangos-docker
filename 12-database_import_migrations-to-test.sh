#!/bin/bash

#Get variables defined in .env

source .env

#Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

echo "[VMaNGOS]: Merging database migrations..."

cd ./src/github_core/sql/migrations
./merge.sh
cd "$repository_path"

echo "[VMaNGOS]: Copying database migrations to /vol/database..."

cp -r ./src/github_core/sql/migrations/world_db_updates.sql ./vol/database/migrations/world_db_updates.sql
cp -r ./src/github_core/sql/migrations/characters_db_updates.sql ./vol/database/migrations/characters_db_updates.sql
cp -r ./src/github_core/sql/migrations/logon_db_updates.sql ./vol/database/migrations/logon_db_updates.sql
cp -r ./src/github_core/sql/migrations/logs_db_updates.sql ./vol/database/migrations/logs_db_updates.sql

echo "[VMaNGOS]: Importing migrations..."

docker exec vmangos_database /bin/sh \
  '[ -e /vol/database/migrations/migrations/world_db_updates.sql ] mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos < /vol/database/migrations/world_db_updates.sql'
docker exec vmangos_database /bin/sh \
  '[ -e /vol/database/migrations/characters_db_updates.sql ] mariadb -u mangos -p$MYSQL_ROOT_PASSWORD characters < /vol/database/migrations/characters_db_updates.sql'
docker exec vmangos_database /bin/sh \ 
  '[ -e /vol/database/migrations/logon_db_updates.sql ] mariadb -u mangos -p$MYSQL_ROOT_PASSWORD realmd < /vol/database/migrations/logon_db_updates.sql'
docker exec vmangos_database /bin/sh \ 
  '[ -e /vol/database/migrations/logs_db_updates.sql ] mariadb -u mangos -p$MYSQL_ROOT_PASSWORD logs < /vol/database/migrations/logs_db_updates.sql'

echo "[VMaNGOS]: Importing database updates..."
