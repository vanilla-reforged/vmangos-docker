#!/bin/bash

# Get variables defined in .env

source .env-script

# Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

# Start

echo "[VMaNGOS]: Removing old target directories..."
rm -r ./vol/core-github
rm -r ./vol/database-github

echo "[VMaNGOS]: Cloning github repositories..."
git clone $VMANGOS_GIT_SOURCE_CORE_URL ./vol/core-github/
git clone $VMANGOS_GIT_SOURCE_DATABASE_URL ./vol/database-github/

echo "[VMaNGOS]: Extracting VMaNGOS world database with 7zip..."
cd ./vol/database-github
7z e $VMANGOS_WORLD_DATABASE.7z
cd "$repository_path"

echo "[VMaNGOS]: Merging VMaNGOS core migrations..."
cd ./vol/core-github/sql/migrations
./merge.sh
cd "$repository_path"

echo "[VMaNGOS]: VMaNGOS data prepared."