#!/bin/bash

# get variables defined in .env

source .env

# Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

echo "[VMaNGOS]: Compiling VMaNGOS..."

# Build compiler image

docker build \
  --build-arg DEBIAN_FRONTEND=noninteractive \
  --no-cache \
  -t vmangos_build \
  -f ./docker/build/Dockerfile .

# Run compiler image

docker run \
  -v "$repository_path/src/github_core:/src/github_core" \
  -v "$repository_path/vol/core:/vol/core" \
  -v "$repository_path/volu/cache:/vol/ccache" \
  -e CCACHE_DIR=$CCACHE_DIR \
  -e VMANGOS_THREADS=$VMANGOS_THREADS \
  -e VMANGOS_DEBUG=$VMANGOS_DEBUG \
  -e VMANGOS_MALLOC=$VMANGOS_MALLOC \
  -e VMANGOS_CLIENT=$VMANGOS_CLIENT \
  -e VMANGOS_EXTRACTORS=$VMANGOS_EXTRACTORS \
  -e VMANGOS_ANTICHEAT=$VMANGOS_ANTICHEAT \
  -e VMANGOS_SCRIPTS=$VMANGOS_SCRIPTS \
  -e VMANGOS_LIBCURL=$VMANGOS_LIBCURL \
  -e VMANGOS_WORLD_DATABASE=$VMANGOS_WORLD_DATABASE \
  --rm \
  vmangos_build

echo "[VMaNGOS]: Compiling complete!"
