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

cd /src/github_database
7z e ${VMANGOS_WORLD_DATABASE}.7z

echo "[VMaNGOS]: Merging VMaNGOS core migrations..."

cd /src/github_core/sql/migrations
./merge.sh

echo "[VMaNGOS]: Building VMaNGOS database container image..."

#Build db image

docker build \
  --build-arg DEBIAN_FRONTEND=noninteractive \
  --no-cache \
  -t vmangos_build \
  -f ./docker/database/Dockerfile

echo "[VMaNGOS]: VMaNGOS database container image built!"
