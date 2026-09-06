#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly CONTAINER_NAME="vmangos-database"
readonly SERVICE_NAME="vmangos-database"
readonly COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

exec_sql() {
    local command="$1"

    sudo docker exec \
        -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" \
        -i "$CONTAINER_NAME" \
        mariadb -u root \
        -e "$command"
}

main() {
    local db
    local entry
    local database
    local sql_file

    local databases=(
        "realmd"
        "characters"
        "mangos"
        "logs"
    )

    log_message "INFO" "Script started"

    # Load environment variables
    source "$PROJECT_ROOT/.env-script"

    # Check for existing databases
    log_message "INFO" "Checking for existing VMaNGOS databases"

    for db in "${databases[@]}"; do
        if exec_sql "SHOW DATABASES LIKE '$db';" | grep -qx "$db"; then
            log_message "ERROR" \
                "Database already exists: $db"
            return 1
        fi
    done

    # Create databases
    log_message "INFO" "Creating VMaNGOS databases"

    for db in "${databases[@]}"; do
        exec_sql \
            "CREATE DATABASE $db DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"

        log_message "SUCCESS" "Created database: $db"
    done

    # Create database user
    log_message "INFO" "Creating mangos database user"

    exec_sql \
        "CREATE USER 'mangos'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"

    exec_sql \
        "GRANT ALL PRIVILEGES ON *.* TO 'mangos'@'%';"

    exec_sql "FLUSH PRIVILEGES;"

    log_message "SUCCESS" "Database user created and privileges granted"

    # Database imports
    local import_files=(
        "mangos:$PROJECT_ROOT/vol/database-github/$VMANGOS_WORLD_DATABASE.sql"
        "realmd:$PROJECT_ROOT/vol/core-github/sql/logon.sql"
        "logs:$PROJECT_ROOT/vol/core-github/sql/logs.sql"
        "characters:$PROJECT_ROOT/vol/core-github/sql/characters.sql"
        "mangos:$PROJECT_ROOT/vol/core-github/sql/migrations/world_db_updates.sql"
        "characters:$PROJECT_ROOT/vol/core-github/sql/migrations/characters_db_updates.sql"
        "realmd:$PROJECT_ROOT/vol/core-github/sql/migrations/logon_db_updates.sql"
        "logs:$PROJECT_ROOT/vol/core-github/sql/migrations/logs_db_updates.sql"
    )

    log_message "INFO" "Importing VMaNGOS databases"

    for entry in "${import_files[@]}"; do
        database="${entry%%:*}"
        sql_file="${entry#*:}"

        if [ ! -f "$sql_file" ]; then
            log_message "ERROR" "SQL file not found: $sql_file"
            return 1
        fi

        log_message "INFO" \
            "Importing ${sql_file##*/} into $database"

        sudo docker exec \
            -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" \
            -i "$CONTAINER_NAME" \
            mariadb -u root "$database" \
            < "$sql_file"

        log_message "SUCCESS" \
            "Imported ${sql_file##*/} into $database"
    done

    # Enable MariaDB binary logging
    log_message "INFO" "Configuring MariaDB binary logging"

    sudo docker exec -i "$CONTAINER_NAME" \
        sh -c "printf '\n[mysqld]\nlog-bin=mysql-bin\nexpire_logs_days=7\n' >> /etc/mysql/my.cnf"

    # Configure default realm
    log_message "INFO" "Creating default realm"

    exec_sql "
        INSERT INTO realmd.realmlist (
            name,
            address,
            port,
            icon,
            realmflags,
            timezone,
            allowedSecurityLevel,
            population,
            gamebuild_min,
            gamebuild_max,
            flag,
            realmbuilds
        ) VALUES (
            '$VMANGOS_REALM_NAME',
            '$VMANGOS_REALM_IP',
            '$VMANGOS_REALM_PORT',
            '$VMANGOS_REALM_ICON',
            '$VMANGOS_REALM_FLAGS',
            '$VMANGOS_TIMEZONE',
            '$VMANGOS_ALLOWED_SECURITY_LEVEL',
            '$VMANGOS_POPULATION',
            '$VMANGOS_GAMEBUILD_MIN',
            '$VMANGOS_GAMEBUILD_MAX',
            '$VMANGOS_FLAG',
            ''
        );
    "

    log_message "SUCCESS" "Default realm configured"

    # Restart database service to apply MariaDB configuration
    log_message "INFO" "Restarting database service"

    sudo docker compose \
        --project-directory "$PROJECT_ROOT" \
        -f "$COMPOSE_FILE" \
        stop "$SERVICE_NAME"

    sudo docker compose \
        --project-directory "$PROJECT_ROOT" \
        -f "$COMPOSE_FILE" \
        up -d "$SERVICE_NAME"

    log_message "SUCCESS" "Database creation completed successfully"
    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
