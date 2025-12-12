#!/bin/bash
# Run with nice (CPU priority 19) and ionice (I/O priority class 2, level 7)
# This is a heavy multi-database backup process, so use maximum niceness
nice -n 19 ionice -c 2 -n 7 bash -c '
# Define variables
BACKUP_DIR="/vol/backup"
DB_USER="mangos"
DB_PASS="$MYSQL_ROOT_PASSWORD"
# Create the full SQL dump
echo "Creating full SQL dump..."
mariadb-dump \
  --user="$DB_USER" --password="$DB_PASS" \
  --single-transaction --quick \
  --master-data=2 \
  --databases characters logs realmd \
  > "$BACKUP_DIR/full_backup.sql"
if [[ $? -eq 0 ]]; then
    echo "Full SQL dump created successfully in $BACKUP_DIR."
else
    echo "Failed to create full SQL dump!"
    exit 1
fi
'
