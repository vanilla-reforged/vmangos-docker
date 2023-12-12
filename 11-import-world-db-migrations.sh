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
# Restart environment to make new files visible inside container volume
docker compose down
sleep 30s
docker compose up -d
sleep 30s
# Execute sh script inside container
docker exec vmangos_database /import-world-db-migrations.sh
