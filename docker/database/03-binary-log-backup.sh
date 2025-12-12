#!/bin/bash
# Copy CLOSED MariaDB binlogs into /vol/backup (inside container)
# Option 2: host will compress each binlog individually

set -euo pipefail

# Be nice to the system
renice -n 19 $$ >/dev/null 2>&1 || true
ionice -c 3 -p $$ >/dev/null 2>&1 || true

CONTAINER_BACKUP_DIR="/vol/backup"
MYSQL_DATA_DIR="/var/lib/mysql"
DB_USER="mangos"
DB_PASS="$MYSQL_ROOT_PASSWORD"

echo "[INFO] Starting binlog copy (inside container)"
mkdir -p "$CONTAINER_BACKUP_DIR"

echo "[INFO] FLUSH BINARY LOGS (rotate)"
mariadb --user="$DB_USER" --password="$DB_PASS" -e "FLUSH BINARY LOGS;"

# Only match real binlog files
pattern="$MYSQL_DATA_DIR/mysql-bin."[0-9][0-9][0-9][0-9][0-9][0-9]

latest_binlog=$(ls -1 $pattern | sort | tail -n 1)
echo "[INFO] Active binlog (skip): $(basename "$latest_binlog")"

for binlog in $(ls -1 $pattern | sort); do
  [[ "$binlog" == "$latest_binlog" ]] && continue

  name="$(basename "$binlog")"
  dst="$CONTAINER_BACKUP_DIR/$name"

  # IMPORTANT: skip if already copied OR already compressed by host
  if [[ -f "$dst" || -f "$dst.7z" ]]; then
    echo "[INFO] Skipping already present $name (raw or .7z)"
    continue
  fi

  echo "[INFO] Copying $name"
  dd if="$binlog" of="$dst" bs=1M iflag=fullblock status=none
  sync
  sleep 1
done

echo "[INFO] Binlog copy completed"
