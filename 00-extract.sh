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

# Replace if needed; e.g., to match your host user/group ID
user_id=1000
group_id=1000

# Replace with different client version, if required
# See https://github.com/vmangos/core#currently-supported-builds
client_version=5875

# Replace with a different world database import name in case there is an
# update
world_database_import_name=world_full_14_june_2021

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

repository_path=$(dirname "$(get_script_path "$0")")

cd "$repository_path"

echo "[VMaNGOS]: Stopping potentially running containers..."

docker-compose down

echo "[VMaNGOS]: Removing old files..."

rm -rf ./vmangos/*
rm -rf ./src/ccache/*

echo "[VMaNGOS]: Updating submodules..."

git submodule update --init --remote --recursive

echo "[VMaNGOS]: Building VMaNGOS..."

docker build \
  --build-arg VMANGOS_USER_ID=$user_id \
  --build-arg VMANGOS_GROUP_ID=$group_id \
  --no-cache \
  -t vmangos_build \
  -f ./docker/build/Dockerfile .

docker run \
  -v "$repository_path/vmangos:/vmangos" \
  -v "$repository_path/src/database:/database" \
  -v "$repository_path/src/world_database:/world_database" \
  -v "$repository_path/src/ccache:/ccache" \
  -e CCACHE_DIR=/ccache \
  -e VMANGOS_CLIENT=$client_version \
  -e VMANGOS_WORLD=$world_database_import_name \
  -e VMANGOS_THREADS=$((`nproc` > 1 ? `nproc` - 1 : 1)) \
  --rm \
  vmangos_build

echo "[VMaNGOS]: Running client data extractors."
echo "[VMaNGOS]: This will take a long time..."

if [ ! -d "./src/client_data/Data" ]; then
  echo "[VMaNGOS]: Client data missing, aborting extraction."
  exit 1
fi

docker build \
  --no-cache \
  -t vmangos_extractors \
  -f ./docker/extractors/Dockerfile .

docker run \
  -v "$repository_path/src/client_data:/client_data" \
  --rm \
  vmangos_extractors \
  /opt/vmangos/bin/mapextractor

docker run \
  -v "$repository_path/src/client_data:/client_data" \
  --rm \
  vmangos_extractors \
  /opt/vmangos/bin/vmapextractor

docker run \
  -v "$repository_path/src/client_data:/client_data" \
  --rm \
  vmangos_extractors \
  /opt/vmangos/bin/vmap_assembler

docker run \
  -v "$repository_path/src/client_data:/client_data" \
  -v "$repository_path/src/core/contrib/mmap:/mmap_contrib" \
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

echo "[VMaNGOS]: Client data extraction complete!"