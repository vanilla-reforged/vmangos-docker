#!/bin/bash
# Change to the directory where the script is located
cd "$(dirname "$0")"
# Load environment variables
source ./../../.env-script

# Define paths and Docker image
CLIENT_DATA_DIR="$DOCKER_DIRECTORY/vol/client-data/Data"
EXTRACTORS_IMAGE="vmangos_extractors"
EXTRACTORS_DOCKERFILE="$DOCKER_DIRECTORY/docker/extractors/Dockerfile"

# Define volumes as an array of complete -v arguments
EXTRACTORS_VOLUMES=(
    "-v" "$DOCKER_DIRECTORY/vol/client-data:/vol/client-data"
    "-v" "$DOCKER_DIRECTORY/vol/core:/vol/core"
)

EXTRACTORS_COMMANDS=(
    "/vol/core/bin/Extractors/MapExtractor"
    "/vol/core/bin/Extractors/VMapExtractor"
    "/vol/core/bin/Extractors/VMapAssembler"
    "/vol/core/bin/Extractors/MoveMapGenerator --offMeshInput /vol/core/bin/Extractors/offmesh.txt"
)

EXTRACTED_DATA_DIR="$DOCKER_DIRECTORY/vol/client-data-extracted/$VMANGOS_CLIENT"

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
        "${EXTRACTORS_VOLUMES[@]}" \
        --rm \
        "$EXTRACTORS_IMAGE" \
        $CMD || { echo "Extraction command '$CMD' failed."; exit 1; }
done

# Clean up unused data
rm -rf "$DOCKER_DIRECTORY/vol/client-data/Buildings"

# Remove potentially existing partial data and create directories
rm -rf "$DOCKER_DIRECTORY/vol/client-data-extracted/"*
mkdir -p "5875"

# Move extracted data to the correct location
mv "$DOCKER_DIRECTORY/vol/client-data/dbc" "$DOCKER_DIRECTORY/vol/client-data-extracted/5875/"
mv "$DOCKER_DIRECTORY/vol/client-data/maps" "$DOCKER_DIRECTORY/vol/client-data-extracted/"
mv "$DOCKER_DIRECTORY/vol/client-data/mmaps" "$DOCKER_DIRECTORY/vol/client-data-extracted/"
mv "$DOCKER_DIRECTORY/vol/client-data/vmaps" "$DOCKER_DIRECTORY/vol/client-data-extracted/"

echo "[VMaNGOS]: Client data extraction complete!"
