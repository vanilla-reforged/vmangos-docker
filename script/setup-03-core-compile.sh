#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly IMAGE_NAME="vmangos-build"
readonly DOCKERFILE_PATH="$PROJECT_ROOT/docker/build/Dockerfile"
readonly BUILD_ENV_FILE="$PROJECT_ROOT/.env-vmangos-build"

readonly CCACHE_DIR="$PROJECT_ROOT/vol/ccache"
readonly CORE_DIR="$PROJECT_ROOT/vol/core"
readonly CORE_GITHUB_DIR="$PROJECT_ROOT/vol/core-github"
readonly CONFIG_DIR="$PROJECT_ROOT/vol/configuration"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

main() {
    log_message "INFO" "Script started"

    # Build compiler image
    log_message "INFO" "Building compiler image"

    sudo docker build \
        --build-arg DEBIAN_FRONTEND=noninteractive \
        --no-cache \
        -t "$IMAGE_NAME" \
        -f "$DOCKERFILE_PATH" \
        "$PROJECT_ROOT/docker/build"

    # Compile VMaNGOS
    log_message "INFO" "Compiling VMaNGOS"

    sudo docker run \
        -v "$CCACHE_DIR:/vol/ccache" \
        -v "$CORE_DIR:/vol/core" \
        -v "$CORE_GITHUB_DIR:/vol/core-github" \
        --env-file "$BUILD_ENV_FILE" \
        --rm \
        "$IMAGE_NAME"

    log_message "SUCCESS" "VMaNGOS compilation completed successfully"

    # Copy default configuration files only when they do not already exist
    mkdir -p "$CONFIG_DIR"

    if [ ! -f "$CONFIG_DIR/mangosd.conf" ]; then
        log_message "INFO" "Copying default mangosd.conf"
        cp "$CORE_DIR/etc/mangosd.conf" "$CONFIG_DIR/mangosd.conf"
    fi

    if [ ! -f "$CONFIG_DIR/realmd.conf" ]; then
        log_message "INFO" "Copying default realmd.conf"
        cp "$CORE_DIR/etc/realmd.conf" "$CONFIG_DIR/realmd.conf"
    fi

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
