#!/bin/bash

# Load environment variables
source .env

# Define paths and Docker image
CLIENT_DATA_DIR="./vol/client-data/Data"
EXTRACTORS_IMAGE="vmangos_extractors"
EXTRACTORS_DOCKERFILE="./docker/extractors/Dockerfile"
EXTRACTORS_VOLUMES=(
  "./vol/client-data:/vol/client-data"
  "./vol/core:/vol/core"
)
EXTRACTORS_COMMANDS=(
  "/vol/core/bin/mapextractor"
  "/vol/core/bin/vmapextractor"
  "/vol/core/bin/vmap_assembler"
  "/vol/core/bin/MoveMapGen --offMeshInput /vol/core/contrib/mmap/offmesh.txt"
)
EXTRACTED_DATA_DIR="./vol/client-data-extracted/$VMANGOS_CLIENT"

# Check if client data exists
if [ ! -d "$CLIENT_DATA_DIR" ]; then
  echo "[VMaNGOS]: Client data missing, aborting extraction."
  exit 1
fi

echo "[VMaNGOS]: Running client data extractors."
echo "[VMaNGOS]: This will take a long time..."

# Build the Docker image
docker build \
  --no-cache \
  -t "$EXTRACTORS_IMAGE" \
  -f "$EXTRACTORS_DOCKERFILE" . || { echo "Failed to build Docker image."; exit 1; }

# Run extraction commands
for CMD in "${EXTRACTORS_COMMANDS[@]}"; do
  docker run \
    "${EXTRACTORS_VOLUMES[@]/#/-v }" \
    --rm \
    "$EXTRACTORS_IMAGE" \
    $CMD || { echo "Extraction command '$CMD' failed."; exit 1; }
done

# Clean up unused data
rm -rf ./vol/client-data/Buildings

# Remove potentially existing partial data and create directories
rm -rf ./vol/client-data-extracted/*
mkdir -p "$EXTRACTED_DATA_DIR"

# Move extracted data to the correct location
mv ./vol/client-data/dbc "$EXTRACTED_DATA_DIR/"
mv ./vol/client-data/maps ./vol/client-data-extracted/
mv ./vol/client-data/mmaps ./vol/client-data-extracted/
mv ./vol/client-data/vmaps ./vol/client-data-extracted/

echo "[VMaNGOS]: Client data extraction complete!"
