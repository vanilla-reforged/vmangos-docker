#!/bin/bash

# get variables defined in .env

source .env

# Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

echo "[VMaNGOS]: Removing old data / target directories"

rm -r ./vol/core_github
rm -r ./vol/database_github

echo "[VMaNGOS]: Cloning github repositories."

git clone $VMANGOS_GIT_SOURCE_CORE_URL ./vol/core_github/
git clone $VMANGOS_GIT_SOURCE_DATABASE_URL ./vol/database_github/

echo "[VMaNGOS]: Cloning github repositories finished."
