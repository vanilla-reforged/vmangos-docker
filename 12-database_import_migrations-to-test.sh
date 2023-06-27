#!/bin/sh

#Get variables defined in .env

source .env

#Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

repository_path=$(dirname "$(get_script_path "$0")")

cd "$repository_path"

echo "[VMaNGOS]: Stopping potentially running containers..."

docker-compose down

echo "[VMaNGOS]: Removing old files..."

rm -rf ./vmangos/*
rm -rf ./src/ccache/*

echo "[VMaNGOS]: Updating submodules..."

git submodule update --init --remote --recursive

echo "[VMaNGOS]: Building VMaNGOS..."

docker build \
  --build-arg VMANGOS_USER_ID=$user_id \
  --build-arg VMANGOS_GROUP_ID=$group_id \
  --no-cache \
  -t vmangos_build \
  -f ./docker/build/Dockerfile .

docker run \
  -v "$repository_path/vmangos:/vmangos" \
  -v "$repository_path/src/database:/database" \
  -v "$repository_path/src/world_database:/world_database" \
  -v "$repository_path/src/ccache:/ccache" \
  -e CCACHE_DIR=/ccache \
  -e VMANGOS_CLIENT=$client_version \
  -e VMANGOS_WORLD=$world_database_import_name \
  -e VMANGOS_THREADS=$((`nproc` > 1 ? `nproc` - 1 : 1)) \
  --rm \
  vmangos_build

echo "[VMaNGOS]: Merging database migrations..."

cd ./src/core/sql/migrations
./merge.sh
cd "$repository_path"

echo "[VMaNGOS]: Rebuilding containers..."

docker-compose build --no-cache

echo "[VMaNGOS]: Recreating database container..."

docker-compose up -d vmangos_database

echo "[VMaNGOS]: Waiting a minute for the database to settle..."

sleep 60

echo "[VMaNGOS]: Importing database updates..."

docker-compose exec -T vmangos_database sh -c \
  '[ -e /opt/vmangos/sql/world_database/$VMANGOS_WORLD.sql ] && mysql -u root -p$MYSQL_ROOT_PASSWORD < /sql/regenerate-world-db.sql && mysql -u root -p$MYSQL_ROOT_PASSWORD mangos < /opt/vmangos/sql/world_database/$VMANGOS_WORLD.sql'
docker-compose exec -T vmangos_database sh -c \
  '[ -e /opt/vmangos/sql/migrations/world_db_updates.sql ] && mysql -u root -p$MYSQL_ROOT_PASSWORD mangos < /opt/vmangos/sql/migrations/world_db_updates.sql'
docker-compose exec -T vmangos_database sh -c \
  '[ -e /opt/vmangos/sql/migrations/characters_db_updates.sql ] && mysql -u root -p$MYSQL_ROOT_PASSWORD characters < /opt/vmangos/sql/migrations/characters_db_updates.sql'
docker-compose exec -T vmangos_database sh -c \
  '[ -e /opt/vmangos/sql/migrations/logon_db_updates.sql ] && mysql -u root -p$MYSQL_ROOT_PASSWORD realmd < /opt/vmangos/sql/migrations/logon_db_updates.sql'
docker-compose exec -T vmangos_database sh -c \
  '[ -e /opt/vmangos/sql/migrations/logs_db_updates.sql ] && mysql -u root -p$MYSQL_ROOT_PASSWORD logs < /opt/vmangos/sql/migrations/logs_db_updates.sql'

echo "[VMaNGOS]: Recreating other containers..."

docker-compose up -d

echo "[VMaNGOS]: Update complete!"
