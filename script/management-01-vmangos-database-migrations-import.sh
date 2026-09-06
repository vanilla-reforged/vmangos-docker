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

    if [ ! -f "$PROJECT_ROOT/.env-script" ]; then
        log_message "ERROR" "Environment file not found: $PROJECT_ROOT/.env-script"
        return 1
    fi

    source "$PROJECT_ROOT/.env-script"

    log_message "INFO" "Importing database migrations"

    sudo docker exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" -i vmangos-database \
        mariadb -u root mangos \
        < "$PROJECT_ROOT/vol/core-github/sql/migrations/world_db_updates.sql"

    sudo docker exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" -i vmangos-database \
        mariadb -u root characters \
        < "$PROJECT_ROOT/vol/core-github/sql/migrations/characters_db_updates.sql"

    sudo docker exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" -i vmangos-database \
        mariadb -u root realmd \
        < "$PROJECT_ROOT/vol/core-github/sql/migrations/logon_db_updates.sql"

    sudo docker exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" -i vmangos-database \
        mariadb -u root logs \
        < "$PROJECT_ROOT/vol/core-github/sql/migrations/logs_db_updates.sql"

    log_message "SUCCESS" "Database migrations imported successfully"

    log_message "INFO" "Restarting Docker Compose environment"

    sudo docker compose \
        --project-directory "$PROJECT_ROOT" \
        --env-file "$PROJECT_ROOT/.env" \
        -f "$PROJECT_ROOT/docker-compose.yml" \
        down

    sudo docker compose \
        --project-directory "$PROJECT_ROOT" \
        --env-file "$PROJECT_ROOT/.env" \
        -f "$PROJECT_ROOT/docker-compose.yml" \
        up -d

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
