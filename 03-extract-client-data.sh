#!/bin/bash

# Get variables defined in .env

source .env

# Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

# Check if client data exists

 if [ ! -d "./vol/client_data/Data" ]; then
    echo "[VMaNGOS]: Client data missing, aborting extraction."
    exit 1
 fi

echo "[VMaNGOS]: Running client data extractors."
echo "[VMaNGOS]: This will take a long time..."

 docker build \
    --no-cache \
    -t vmangos_extractors \
    -f ./docker/extractors/Dockerfile .

  docker run \
    -v "$repository_path/vol/client_data:/vol/client_data" \
    -v "$repository_path/vol/core:/vol/core" \
    --rm \
    vmangos_extractors \
    /vol/core/bin/mapextractor

  docker run \
    -v "$repository_path/vol/client_data:/vol/client_data" \
    -v "$repository_path/vol/core:/vol/core" \
    --rm \
    vmangos_extractors \
    /vol/core/bin/vmapextractor

  docker run \
    -v "$repository_path/vol/client_data:/vol/client_data" \
    -v "$repository_path/vol/core:/vol/core" \
    --rm \
    vmangos_extractors \
    /vol/core/bin/vmap_assembler

  docker run \
    -v "$repository_path/vol/client_data:/vol/client_data" \
    -v "$repository_path/vol/core:/vol/core" \
    --rm \
    vmangos_extractors \
    /vol/core/bin/MoveMapGen --offMeshInput /vol/core/contrib/mmap/offmesh.txt

  # This data isn't used. delete it to avoid confusion
  rm -rf ./vol/client_data/Buildings

  # Remove potentially existing partial data
  rm -rf ./vol/client_data_extracted/*
  mkdir -p "./vol/client_data_extracted/$VMANGOS_CLIENT"

  mv ./vol/client_data/dbc ./vol/client_data_extracted/$VMANGOS_CLIENT/
  mv ./vol/client_data/maps ./vol/client_data_extracted/
  mv ./vol/client_data/mmaps ./vol/client_data_extracted/
  mv ./vol/client_data/vmaps ./vol/client_data_extracted/

echo "[VMaNGOS]: Client data extraction complete!"
