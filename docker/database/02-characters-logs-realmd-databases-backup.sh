#!/bin/bash

# Define variables
BACKUP_DIR="/vol/backup"
DB_USER="mangos"
DB_PASS="$MYSQL_ROOT_PASSWORD"  # No need to source the environment, it's available in the container

# Create the full SQL dump
echo "Creating full SQL dump..."
mariadb-dump --user="$DB_USER" --password="$DB_PASS" --databases characters logs realmd > "$BACKUP_DIR/full_backup.sql"

if [[ $? -eq 0 ]]; then
    echo "Full SQL dump created successfully in $BACKUP_DIR."
else
    echo "Failed to create full SQL dump!"
    exit 1
fi
