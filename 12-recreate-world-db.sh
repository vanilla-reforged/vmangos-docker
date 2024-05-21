#!/bin/bash

# Get variables defined in .env

source .env

# Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

echo "[VMaNGOS]: Merging VMaNGOS core migrations..."
cd ./vol/core_github/sql/migrations
./merge.sh
cd "$repository_path"

echo "[VMaNGOS]: Restarting environment..."

docker compose down
docker compose up -d

echo "[VMaNGOS]: Wait for DB..."

sleep 45

# Start
docker exec vmangos_database /recreate-world-db.sh
