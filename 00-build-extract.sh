#!/bin/sh

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

source ./.env

# Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

echo "[VMaNGOS]: Building VMaNGOS..."

# Build compiler image

docker build \
  --build-arg VMANGOS_USER_ID=$VMANGOS_USER_ID \
  --build-arg VMANGOS_GROUP_ID=$VMANGOS_GROUP_ID \
  --build-arg VMANGOS_GIT_SOURCE_CORE=$VMANGOS_GIT_SOURCE_CORE \
  --build-arg VMANGOS_GIT_SOURCE_DATABAS=$VMANGOS_GIT_SOURCE_DATABASE \
  --no-cache \
  -t vmangos_build \
  -f ./docker/build/Dockerfile .

# Run compiler image

docker run \
  -v "$repository_path/volume/compiled_core:/compiled_core" \
  -v "$repository_path/volume/database:/database" \
  -v "$repository_path/volume/ccache:/ccache" \
  -e CCACHE_DIR=/ccache \
  -e VMANGOS_CLIENT=$VMANGOS_CLIENT_VERSIONn \
  -e VMANGOS_WORLD=$VMANGOS_WORLD_DATABASE \
  -e VMANGOS_THREADS=$((`nproc` > 1 ? `nproc` - 1 : 1)) \
  --user=root \
  --rm \
  vmangos_build

if [ $(ls -l ./src/data | wc -l) -eq 1 ]; then
  echo "[VMaNGOS]: Extracted client data missing, running extractors."
  echo "[VMaNGOS]: This will take a long time..."

  if [ ! -d "./src/client_data/Data" ]; then
    echo "[VMaNGOS]: Client data missing, aborting installation."
    exit 1
  fi

  docker build \
    --no-cache \
    -t vmangos_extractors \
    -f ./docker/extractors/Dockerfile .

  docker run \
    -v "$repository_path/src/client_data:/client_data" \
    --user=root \
    --rm \
    vmangos_extractors \
    /opt/vmangos/bin/mapextractor

  docker run \
    -v "$repository_path/src/client_data:/client_data" \
    --user=root \
    --rm \
    vmangos_extractors \
    /opt/vmangos/bin/vmapextractor

  docker run \
    -v "$repository_path/src/client_data:/client_data" \
    --user=root \
    --rm \
    vmangos_extractors \
    /opt/vmangos/bin/vmap_assembler

  docker run \
    -v "$repository_path/src/client_data:/client_data" \
    -v "$repository_path/src/core/contrib/mmap:/mmap_contrib" \
    --user=root \
    --rm \
    vmangos_extractors \
    /opt/vmangos/bin/MoveMapGen --offMeshInput /mmap_contrib/offmesh.txt

  # This data isn't used. delete it to avoid confusion
  rm -rf ./src/client_data/Buildings

  # Remove potentially existing partial data
  rm -rf ./src/data/*
  mkdir -p "./src/data/$client_version"

  mv ./src/client_data/dbc "./src/data/$client_version/"
  mv ./src/client_data/maps ./src/data/
  mv ./src/client_data/mmaps ./src/data/
  mv ./src/client_data/vmaps ./src/data/
fi

echo "[VMaNGOS]: Creating containers..."

docker-compose build --no-cache
docker-compose up -d

echo "[VMaNGOS]: Installation complete!"
echo "[VMaNGOS]: Please wait a few minutes for the database to get built before trying to access it."
