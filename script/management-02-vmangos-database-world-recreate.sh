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

    readonly DATABASE_CONTAINER="vmangos-database"
    readonly WORLD_DATABASE_FILE="$PROJECT_ROOT/vol/database-github/$VMANGOS_WORLD_DATABASE.sql"
    readonly WORLD_MIGRATIONS_FILE="$PROJECT_ROOT/vol/core-github/sql/migrations/world_db_updates.sql"

    # Recreate world database
    log_message "INFO" "Recreating world database"

    sudo docker exec \
        -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" \
        -i "$DATABASE_CONTAINER" \
        mariadb -u root \
        -e "DROP DATABASE IF EXISTS mangos; CREATE DATABASE mangos DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"

    # Import world database
    log_message "INFO" "Importing world database"

    sudo docker exec \
        -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" \
        -i "$DATABASE_CONTAINER" \
        mariadb -u root mangos \
        < "$WORLD_DATABASE_FILE"

    # Import world migrations
    log_message "INFO" "Importing world database migrations"

    sudo docker exec \
        -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" \
        -i "$DATABASE_CONTAINER" \
        mariadb -u root mangos \
        < "$WORLD_MIGRATIONS_FILE"

    log_message "SUCCESS" "World database recreated successfully"

    # Restart environment
    log_message "INFO" "Restarting Docker Compose environment"

    sudo docker compose \
        --project-directory "$PROJECT_ROOT" \
        -f "$PROJECT_ROOT/docker-compose.yml" \
        down

    sudo docker compose \
        --project-directory "$PROJECT_ROOT" \
        -f "$PROJECT_ROOT/docker-compose.yml" \
        up -d

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
