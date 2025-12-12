#!/bin/bash
# Binary log backup script (PITR-safe, incremental)
# Runs INSIDE the MariaDB container

set -euo pipefail

# Apply low resource priority to this process
renice -n 19 $$ >/dev/null 2>&1 || true
ionice -c 3 -p $$ >/dev/null 2>&1 || true

# Configuration
CONTAINER_BACKUP_DIR="/vol/backup"
MYSQL_DATA_DIR="/var/lib/mysql"
DB_USER="mangos"
DB_PASS="$MYSQL_ROOT_PASSWORD"

echo "[INFO] Starting binary log backup (inside container)"

# Ensure backup directory exists
mkdir -p "$CONTAINER_BACKUP_DIR"

# 1) Rotate binlogs so the active one is closed
echo "[INFO] Rotating binary logs"
mariadb --user="$DB_USER" --password="$DB_PASS" -e "FLUSH BINARY LOGS;"

# 2) Determine newest (active) binlog after rotation
latest_binlog=$(ls -1 "$MYSQL_DATA_DIR"/mysql-bin.[0-9][0-9][0-9][0-9][0-9][0-9] | sort | tail -n 1)
echo "[INFO] Active binlog: $(basename "$latest_binlog")"

# 3) Copy only CLOSED binlogs that are not yet backed up
for binlog in $(ls -1 "$MYSQL_DATA_DIR"/mysql-bin.[0-9][0-9][0-9][0-9][0-9][0-9] | sort); do
    [[ "$binlog" == "$latest_binlog" ]] && continue

    filename=$(basename "$binlog")
    target="$CONTAINER_BACKUP_DIR/$filename"

    # Skip if already copied
    if [[ -f "$target" ]]; then
        echo "[INFO] Skipping already backed up $filename"
        continue
    fi

    echo "[INFO] Backing up $filename"
    dd if="$binlog" of="$target" bs=1M iflag=fullblock status=none
    sync
    sleep 1
done

echo "[INFO] Binary log backup inside container completed"
