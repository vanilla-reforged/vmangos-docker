#!/bin/bash

# vmangos-docker
# Based on Michael Serajnik's work https://sr.ht/~mser/

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Get .ENV Variables

. .\.env

# Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

echo "[VMaNGOS]: Building VMaNGOS..."

# Build compiler image

docker build \
  --build-arg DEBIAN_FRONTEND=noninteractive \
  --no-cache \
  -t vmangos_build \
  -f ./docker/build/Dockerfile .

# Run compiler image

docker run \
  -v "$repository_path/volume/compiled_core:/compiled_core" \
  -v "$repository_path/volume/database:/database" \
  -v "$repository_path/volume/ccache:/ccache" \
  --env-file=.env
  -e VMANGOS_THREADS=$((`nproc` > 1 ? `nproc` - 1 : 1)) \
  --user=root \
  --rm \
  vmangos_build

  if [ $(ls -l ./volume/client_data_extracted | wc -l) -eq 1 ]; then
    echo "[VMaNGOS]: Extracted client data missing, running extractors."
    echo "[VMaNGOS]: This will take a long time..."

  if [ ! -d "./volume/client_data/Data" ]; then
    echo "[VMaNGOS]: Client data missing, aborting installation."
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
  rm -rf ./volume/client_data_extracted/*
  mkdir -p "./volume/client_data_extracted/$VMANGOS_CLIENT_VERSION"

  mv ./volume/client_data/dbc "./volume/client_data_extracted/$VMANGOS_CLIENT_VERSION/"
  mv ./volume/client_data/maps ./volume/client_data_extracted/
  mv ./volume/client_data/mmaps ./volume/client_data_extracted/
  mv ./volume/client_data/vmaps ./volume/client_data_extracted/
fi

echo "[VMaNGOS]: Creating containers..."

docker-compose build --no-cache
docker-compose up -d

echo "[VMaNGOS]: Installation complete!"
echo "[VMaNGOS]: Please wait a few minutes for the database to get built before trying to access it."
