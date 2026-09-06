#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly CORE_DIR="$PROJECT_ROOT/vol/core"
readonly CORE_GITHUB_DIR="$PROJECT_ROOT/vol/core-github"
readonly CCACHE_DIR="$PROJECT_ROOT/vol/ccache"

readonly COMPILER_IMAGE="vmangos-build"
readonly DOCKERFILE="$PROJECT_ROOT/docker/build/Dockerfile"
readonly BUILD_ENV_FILE="$PROJECT_ROOT/.env-vmangos-build"
readonly COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

main() {
    log_message "INFO" "Script started"

    log_message "INFO" "Stopping Docker Compose environment"

    sudo docker compose \
        --project-directory "$PROJECT_ROOT" \
        --env-file "$PROJECT_ROOT/.env" \
        -f "$COMPOSE_FILE" \
        down

    log_message "INFO" "Removing old core and build files"

    rm -rf \
        "$CORE_DIR" \
        "$CORE_GITHUB_DIR/build"

    log_message "INFO" "Building compiler image"

    sudo docker build \
        --build-arg DEBIAN_FRONTEND=noninteractive \
        --no-cache \
        -t "$COMPILER_IMAGE" \
        -f "$DOCKERFILE" \
        "$PROJECT_ROOT/docker/build"

    log_message "INFO" "Compiling VMaNGOS"

    sudo docker run \
        -v "$CORE_DIR:/vol/core" \
        -v "$CORE_GITHUB_DIR:/vol/core-github" \
        -v "$CCACHE_DIR:/vol/ccache" \
        --env-file "$BUILD_ENV_FILE" \
        --rm \
        "$COMPILER_IMAGE"

    log_message "SUCCESS" "VMaNGOS compilation completed"

    log_message "INFO" "Starting Docker Compose environment"

    sudo docker compose \
        --project-directory "$PROJECT_ROOT" \
        --env-file "$PROJECT_ROOT/.env" \
        -f "$COMPOSE_FILE" \
        up --build -d

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
