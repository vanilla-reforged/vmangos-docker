#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables from .env-script
source ./../../.env-script  # Adjusted to load .env-script from the project root using $DOCKER_DIRECTORY

# Define Docker image and container details
IMAGE_NAME="vmangos-build"
DOCKERFILE_PATH="$DOCKER_DIRECTORY/docker/build/Dockerfile"  # Use $DOCKER_DIRECTORY for the correct path
VOLUMES=(
  "$DOCKER_DIRECTORY/vol/ccache:/vol/ccache"
  "$DOCKER_DIRECTORY/vol/core:/vol/core"
  "$DOCKER_DIRECTORY/vol/core-github:/vol/core-github"
)
ENV_FILE="$DOCKER_DIRECTORY/.env-vmangos-build"  # Use $DOCKER_DIRECTORY for the env file

echo "[VMaNGOS]: Building compiler image..."

# Build the Docker image and handle errors
docker build \
  --build-arg DEBIAN_FRONTEND=noninteractive \
  --no-cache \
  -t "$IMAGE_NAME" \
  -f "$DOCKERFILE_PATH" . || { echo "Failed to build Docker image."; exit 1; }

echo "[VMaNGOS]: Compiling VMaNGOS..."

# Compile using the Docker image
docker run \
  $(printf '%s ' "${VOLUMES[@]/#/ -v }") \
  --env-file "$ENV_FILE" \
  --rm \
  "$IMAGE_NAME" || { echo "Compilation failed."; exit 1; }

echo "[VMaNGOS]: Compiling complete!"
