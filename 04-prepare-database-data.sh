#!/bin/bash

#Get variables defined in .env

source .env

#Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

echo "[VMaNGOS]: Extracting VMaNGOS world database..."

cd ./src/github_database
7z e $VMANGOS_WORLD_DATABASE.7z
cd "$repository_path"

echo "[VMaNGOS]: Merging VMaNGOS core migrations..."

cd ./src/github_core/sql/migrations
./merge.sh
cd "$repository_path"

echo "[VMaNGOS]: VMaNGOS data prepared."