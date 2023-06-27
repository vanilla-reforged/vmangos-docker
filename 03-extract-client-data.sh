#!/bin/sh

#Get variables defined in .env

source .env

#Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

#Check if client data exists

 if [ ! -d "./src/client_data/data" ]; then
    echo "[VMaNGOS]: Client data missing, aborting extraction."
    exit 1
 fi

#Copy extractors from /vol/core to /src/extractors

cp ./vol/core/bin/mapextractor ./src/extractors/
cp ./vol/core/bin/vmapextractor ./src/extractors/
cp ./vol/core/bin/vmap_assembler ./src/extractors/
cp ./vol/core/bin/MoveMapGen ./src/extractors/

echo "[VMaNGOS]: Running client data extractors."
echo "[VMaNGOS]: This will take a long time..."

 docker build \
    --no-cache \
    -t vmangos_extractors \
    -f ./docker/extractors/Dockerfile .

  docker run \
    -v "$repository_path/src/client_data:/src/client_data" \
    --user=root \
    --rm \
    vmangos_extractors \
    /vol/core/bin/mapextractor

  docker run \
    -v "$repository_path/src/client_data:/src/client_data" \
    --user=root \
    --rm \
    vmangos_extractors \
    /vol/core/bin/vmapextractor

  docker run \
    -v "$repository_path/src/client_data:/src/client_data" \
    --user=root \
    --rm \
    vmangos_extractors \
    /vol/core/bin/vmap_assembler

  docker run \
    -v "$repository_path/src/client_data:/src/client_data" \
    -v "$repository_path/vol/core/contrib/mmap:/vol/core/contrib/mmap" \
    --user=root \
    --rm \
    vmangos_extractors \
    /vol/core/bin/MoveMapGen --offMeshInput /vol/core/contrib/mmap/offmesh.txt

  # This data isn't used. delete it to avoid confusion
  rm -rf ./src/client_data/Buildings

  # Remove potentially existing partial data
  # rm -rf ./vol/server_data/data/*
  # mkdir -p "./vol/server_data/data/$VMANGOS_CLIENT_VERSION"

  mv ./src/client_data/dbc "./vol/server_data/$VMANGOS_CLIENT_VERSION/"
  mv ./src/client_data/maps ./vol/server_data/
  mv ./src/client_data/mmaps ./vol/server_data/
  mv ./src/client_data/vmaps ./vol/server_data/

echo "[VMaNGOS]: Client data extraction complete!"
