#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Define variables
CORE_DIR="./vol/core"
CORE_GITHUB_DIR="./vol/core-github"
COMPILER_IMAGE="vmangos_build"
DOCKERFILE="./docker/build/Dockerfile"

# Function to handle errors
handle_error() {
  echo "[VMaNGOS]: Error occurred: $1"
  exit 1
}

# Shut down the environment
echo "[VMaNGOS]: Shutting down environment..."
docker compose down || handle_error "Failed to shut down environment"

# Remove old files
echo "[VMaNGOS]: Removing old core and installation files..."
rm -rf "$CORE_DIR" "$CORE_GITHUB_DIR/build" || handle_error "Failed to remove old files"

# Build the compiler image
echo "[VMaNGOS]: Building compiler image..."
docker build --build-arg DEBIAN_FRONTEND=noninteractive --no-cache -t "$COMPILER_IMAGE" -f "$DOCKERFILE" . || handle_error "Failed to build compiler image"

# Compile VMaNGOS
echo "[VMaNGOS]: Compiling VMaNGOS..."
docker run \
  -v "$CORE_DIR:/vol/core" \
  -v "$CORE_GITHUB_DIR:/vol/core-github" \
  -v "./vol/ccache:/vol/ccache" \
  --env-file .env-vmangos-build \
  --rm \
  "$COMPILER_IMAGE" || handle_error "Compilation failed"

echo "[VMaNGOS]: Compiling complete!"

# Start the environment with rebuild
echo "[VMaNGOS]: Starting environment..."
docker compose up --build -d || handle_error "Failed to start environment"

echo "[VMaNGOS]: Environment started successfully."
