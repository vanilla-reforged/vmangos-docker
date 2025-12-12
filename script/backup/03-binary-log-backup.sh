#!/bin/bash
set -euo pipefail

log_message() {
  local level="$1"
  local message="$2"
  local script_name
  script_name=$(basename "$0")
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] [$script_name] [$level] $message"
}

cd "$(dirname "$0")"
log_message "INFO" "Script started"

source ./../../.env-script

BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"

log_message "INFO" "Running binlog copy inside container"
sudo docker exec vmangos-database /home/default/scripts/03-binary-log-backup.sh
log_message "SUCCESS" "Container binlog copy completed"

# Optional: remove old accidental .idx files (doesn't hurt if none exist)
rm -f "$BACKUP_DIR"/mysql-bin.[0-9][0-9][0-9][0-9][0-9][0-9].idx || true

log_message "INFO" "Compressing each binlog individually"

shopt -s nullglob
for f in "$BACKUP_DIR"/mysql-bin.[0-9][0-9][0-9][0-9][0-9][0-9]; do
  base="$(basename "$f")"
  archive="$BACKUP_DIR/$base.7z"

  # Skip if already compressed (paranoia)
  if [[ -f "$archive" ]]; then
    log_message "INFO" "Already compressed: $base"
    rm -f "$f"  # raw file not needed anymore
    continue
  fi

  log_message "INFO" "7z -> $base.7z"
  7z a -bd -y "$archive" "$f" >/dev/null

  # Verify archive created and non-empty, then delete raw
  if [[ -s "$archive" ]]; then
    rm -f "$f"
    log_message "SUCCESS" "Compressed and removed raw: $base"
  else
    log_message "ERROR" "Archive missing/empty for $base (keeping raw)"
    exit 1
  fi
done
shopt -u nullglob

log_message "INFO" "Script completed successfully"
