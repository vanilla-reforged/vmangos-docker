#!/bin/bash

# Define Docker image and container details
IMAGE_NAME="vmangos-build"
DOCKERFILE_PATH="./docker/build/Dockerfile"
VOLUMES=(
  "./vol/ccache:/vol/ccache"
  "./vol/core:/vol/core"
  "./vol/core-github:/vol/core-github"
)
ENV_FILE=".env-vmangos-build"

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
