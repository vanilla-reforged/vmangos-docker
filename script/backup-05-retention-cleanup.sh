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

HOST_BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"
BACKUP_RETENTION_DAYS=8

log_message "INFO" "Using backup directory: $HOST_BACKUP_DIR"
log_message "INFO" "Retention: $BACKUP_RETENTION_DAYS days"

send_discord_message() {
  local message=$1
  if curl -s -H "Content-Type: application/json" \
      -X POST -d "{\"content\": \"$message\"}" \
      "$DISCORD_WEBHOOK" >/dev/null; then
    log_message "SUCCESS" "Discord message sent"
  else
    log_message "ERROR" "Failed to send Discord message"
  fi
}

log_message "INFO" "Finding .7z files older than $BACKUP_RETENTION_DAYS days"

deleted_count=0
total_kb=0

while IFS= read -r file; do
  file_kb=$(du -k "$file" | cut -f1)
  total_kb=$((total_kb + file_kb))
  rm -f "$file"
  ((++deleted_count))
  log_message "INFO" "Deleted: $(basename "$file") (${file_kb} KB)"
done < <(
  find "$HOST_BACKUP_DIR" -type f -name "*.7z" -mtime +"$BACKUP_RETENTION_DAYS"
)

if (( total_kb >= 1024 )); then
  total_mb=$(echo "scale=2; $total_kb/1024" | bc)
  msg="Deleted $deleted_count .7z files older than $BACKUP_RETENTION_DAYS days (freed ~${total_mb} MB)."
else
  msg="Deleted $deleted_count .7z files older than $BACKUP_RETENTION_DAYS days (freed ~${total_kb} KB)."
fi

log_message "SUCCESS" "$msg"
send_discord_message "$msg"

log_message "INFO" "Script completed successfully"
