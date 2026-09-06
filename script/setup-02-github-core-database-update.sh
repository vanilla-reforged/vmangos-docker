#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

main() {
    log_message "INFO" "Script started"

    # Load environment variables
    source "$PROJECT_ROOT/.env-script"

    readonly CORE_GITHUB_DIR="$PROJECT_ROOT/vol/core-github"
    readonly DATABASE_GITHUB_DIR="$PROJECT_ROOT/vol/database-github"
    readonly MIGRATIONS_DIR="$CORE_GITHUB_DIR/sql/migrations"

    # Remove old repositories
    log_message "INFO" "Removing old GitHub repositories"

    rm -rf \
        "$CORE_GITHUB_DIR" \
        "$DATABASE_GITHUB_DIR"

    # Clone repositories
    log_message "INFO" "Cloning VMaNGOS core repository"

    git clone \
        "$VMANGOS_GIT_SOURCE_CORE_URL" \
        "$CORE_GITHUB_DIR"

    log_message "INFO" "Cloning VMaNGOS database repository"

    git clone \
        "$VMANGOS_GIT_SOURCE_DATABASE_URL" \
        "$DATABASE_GITHUB_DIR"

    # Extract world database
    log_message "INFO" "Extracting VMaNGOS world database"

    (
        cd "$DATABASE_GITHUB_DIR"
        7z e "${VMANGOS_WORLD_DATABASE}.7z"
    )

    # Merge core migrations
    log_message "INFO" "Merging VMaNGOS core migrations"

    (
        cd "$MIGRATIONS_DIR"
        ./merge.sh
    )

    log_message "SUCCESS" "VMaNGOS data prepared successfully"
    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
