#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly CLIENT_DATA_DIR="$PROJECT_ROOT/vol/client-data"
readonly CORE_DIR="$PROJECT_ROOT/vol/core"

readonly EXTRACTORS_IMAGE="vmangos_extractors"
readonly EXTRACTORS_DOCKERFILE="$PROJECT_ROOT/docker/extractors/Dockerfile"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

main() {
    local extracted_data_dir
    local extractor_command

    local extractor_commands=(
        "/vol/core/bin/Extractors/MapExtractor"
        "/vol/core/bin/Extractors/VMapExtractor"
        "/vol/core/bin/Extractors/VMapAssembler"
        "/vol/core/bin/Extractors/MoveMapGenerator"
    )

    log_message "INFO" "Script started"

    if [ ! -f "$PROJECT_ROOT/.env-script" ]; then
        log_message "ERROR" "Environment file not found: $PROJECT_ROOT/.env-script"
        return 1
    fi

    source "$PROJECT_ROOT/.env-script"

    extracted_data_dir="$PROJECT_ROOT/vol/client-data-extracted"

    if [ ! -d "$CLIENT_DATA_DIR/Data" ]; then
        log_message "ERROR" "Client data not found: $CLIENT_DATA_DIR/Data"
        return 1
    fi

    log_message "INFO" "Building extractor image"

    sudo docker build \
        --no-cache \
        -t "$EXTRACTORS_IMAGE" \
        -f "$EXTRACTORS_DOCKERFILE" \
        "$PROJECT_ROOT/docker/extractors"

    log_message "INFO" "Running client data extractors"
    log_message "INFO" "Extraction may take a long time"

    for extractor_command in "${extractor_commands[@]}"; do
        log_message "INFO" "Running ${extractor_command##*/}"

        sudo docker run \
            -v "$CLIENT_DATA_DIR:/vol/client-data" \
            -v "$CORE_DIR:/vol/core" \
            --rm \
            "$EXTRACTORS_IMAGE" \
            "$extractor_command"

        log_message "SUCCESS" \
            "Completed ${extractor_command##*/}"
    done

    log_message "INFO" "Removing temporary extractor data"

    rm -rf \
        "$CLIENT_DATA_DIR/Buildings" \
        "$CLIENT_DATA_DIR/Cameras"

    log_message "INFO" "Preparing extracted data directory"

    rm -rf "$extracted_data_dir"
    mkdir -p "$extracted_data_dir/$VMANGOS_CLIENT"

    log_message "INFO" "Moving extracted client data"

    mv \
        "$CLIENT_DATA_DIR/dbc" \
        "$extracted_data_dir/$VMANGOS_CLIENT/dbc"

    mv \
        "$CLIENT_DATA_DIR/maps" \
        "$extracted_data_dir/maps"

    mv \
        "$CLIENT_DATA_DIR/mmaps" \
        "$extracted_data_dir/mmaps"

    mv \
        "$CLIENT_DATA_DIR/vmaps" \
        "$extracted_data_dir/vmaps"

    log_message "SUCCESS" "Client data extraction completed successfully"
    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
