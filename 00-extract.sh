#!/bin/sh

#Get variables defined in .env

source .env

#Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

echo "[VMaNGOS]: Stopping potentially running containers..."

docker-compose down

echo "[VMaNGOS]: Removing old files..."

rm -rf ./volumes/ccache/*

echo "[VMaNGOS]: Running client data extractors."
echo "[VMaNGOS]: This will take a long time..."

 if [ ! -d "./volume/client_data/Data" ]; then
    echo "[VMaNGOS]: Client data missing, aborting extraction."
    exit 1
 fi

 docker build \
    --no-cache \
    --build-arg VMANGOS_USER_ID=$VMANGOS_USER_ID \
    --build-arg VMANGOS_GROUP_ID=$VMANGOS_GROUP_ID \
    -t vmangos_extractors \
    -f ./docker/extractors/Dockerfile .

  docker run \
    -v "$repository_path/volume/client_data:/client_data" \
    --user=root \
    --rm \
    vmangos_extractors \
    /opt/extract/bin/mapextractor

  docker run \
    -v "$repository_path/volume/client_data:/client_data" \
    --user=root \
    --rm \
    vmangos_extractors \
    /opt/extract/bin/vmapextractor

  docker run \
    -v "$repository_path/volume/client_data:/client_data" \
    --user=root \
    --rm \
    vmangos_extractors \
    /opt/extract/bin/vmap_assembler

  docker run \
    -v "$repository_path/volume/client_data:/client_data" \
    -v "$repository_path/volume/compiled_core/contrib/mmap:/mmap_contrib" \
    --user=root \
    --rm \
    vmangos_extractors \
    /opt/extract/bin/MoveMapGen --offMeshInput /mmap_contrib/offmesh.txt

  # This data isn't used. delete it to avoid confusion
  rm -rf ./volume/client_data/Buildings

  # Remove potentially existing partial data
  # rm -rf ./volume/data/*
  # mkdir -p "./volume/data/$VMANGOS_CLIENT_VERSION"

  mv ./volume/client_data/dbc "./volume/client_data_extracted/data/$VMANGOS_CLIENT_VERSION/"
  mv ./volume/client_data/maps ./volume/client_data_extracted/data/
  mv ./volume/client_data/mmaps ./volume/client_data_extracted/data/
  mv ./volume/client_data/vmaps ./volume/client_data_extracted/data/

echo "[VMaNGOS]: Client data extraction complete!"
