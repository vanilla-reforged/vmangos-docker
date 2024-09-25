#!/bin/bash

# Load environment variables
source ./../../.env-script

# Start

echo "[VMaNGOS]: Removing old target directories..."
rm -r $DOCKER_DIRECTORY/vol/core-github
rm -r $DOCKER_DIRECTORY/vol/database-github

echo "[VMaNGOS]: Cloning github repositories..."
git clone $VMANGOS_GIT_SOURCE_CORE_URL $DOCKER_DIRECTORY/vol/core-github/
git clone $VMANGOS_GIT_SOURCE_DATABASE_URL $DOCKER_DIRECTORY/vol/database-github/

echo "[VMaNGOS]: Extracting VMaNGOS world database with 7zip..."
cd $DOCKER_DIRECTORY/vol/database-github
7z e $VMANGOS_WORLD_DATABASE.7z
cd "$repository_path"

echo "[VMaNGOS]: Merging VMaNGOS core migrations..."
cd $DOCKER_DIRECTORY/vol/core-github/sql/migrations
./merge.sh
cd "$repository_path"

echo "[VMaNGOS]: VMaNGOS data prepared."
