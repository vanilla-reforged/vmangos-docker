#!/bin/bash
# Binary log backup script (PITR-safe)
# Copies only CLOSED binlogs, never the active one
# Designed for 7-day point-in-time recovery

set -euo pipefail

# Resource limits
NICE_LEVEL=19
IONICE_CLASS=3   # idle
IONICE_LEVEL=0

nice -n $NICE_LEVEL ionice -c $IONICE_CLASS -n $IONICE_LEVEL bash -c '

# Configuration
CONTAINER_BACKUP_DIR="/vol/backup"
MYSQL_DATA_DIR="/var/lib/mysql"
DB_USER="mangos"
DB_PASS="$MYSQL_ROOT_PASSWORD"

echo "[INFO] Starting binary log backup"

# Ensure backup directory exists
mkdir -p "$CONTAINER_BACKUP_DIR"

# 1) Rotate binlogs so the current one is closed
echo "[INFO] Rotating binary logs"
mariadb --user="$DB_USER" --password="$DB_PASS" -e "FLUSH BINARY LOGS;"

# 2) Identify the newest binlog (still active after rotation)
latest_binlog=$(ls -1 "$MYSQL_DATA_DIR"/mysql-bin.* | sort | tail -n 1)

echo "[INFO] Latest (active) binlog: $(basename "$latest_binlog")"

# 3) Copy all CLOSED binlogs that have not yet been backed up
for binlog in $(ls -1 "$MYSQL_DATA_DIR"/mysql-bin.* | sort); do
    [[ "$binlog" == "$latest_binlog" ]] && continue

    filename=$(basename "$binlog")
    target="$CONTAINER_BACKUP_DIR/$filename"

    # Skip if already backed up
    if [[ -f "$target" ]]; then
        echo "[INFO] Skipping already backed up $filename"
        continue
    fi

    echo "[INFO] Backing up $filename"
    dd if="$binlog" of="$target" bs=1M iflag=fullblock status=none
    sync

    # Small delay to reduce IO pressure
    sleep 1
done

echo "[INFO] Binary log backup completed successfully"
'
