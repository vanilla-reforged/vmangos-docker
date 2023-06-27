#!/bin/bash

# get variables defined in .env

source .env

# Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

echo "[VMaNGOS]: Cloning github repositories."

git clone $VMANGOS_GIT_SOURCE_CORE_URL ./src/github_core/
git clone $VMANGOS_GIT_SOURCE_DATABASE_URL ./src/github_database/

echo "[VMaNGOS]: Cloning github repositories finished."
