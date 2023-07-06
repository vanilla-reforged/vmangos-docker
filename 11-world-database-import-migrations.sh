#!/bin/bash

# Get variables defined in .env

source .env

# Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

# Start

echo "[VMaNGOS]: Removing old target directory..."
rm -r ./vol/core_github

echo "[VMaNGOS]: Cloning github repository..."
git clone $VMANGOS_GIT_SOURCE_CORE_URL ./vol/core_github/

echo "[VMaNGOS]: Cloning github repository finished."
echo "[VMaNGOS]: Merging VMaNGOS core migrations..."
cd ./vol/core_github/sql/migrations
./merge.sh
cd "$repository_path"

echo "[VMaNGOS]: Importing world db migrations..."
docker exec vmangos_database /bin/sh 'mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos < /vol/core_github/sql/migrations/world_db_updates.sql'

echo "[VMaNGOS]: Import finished."
