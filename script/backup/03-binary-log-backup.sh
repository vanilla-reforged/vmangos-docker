#!/bin/bash
cd "$(dirname "$0")"
source ./../../.env-script

DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK"
BACKUP_DIR="$DOCKER_DIRECTORY/vol/backup"
DISCORD_LOG_FILE="/tmp/discord_cumulative_log.txt"

log_and_send_discord() {
   local message=$1
   echo "[$(date)] $message" >> "$DISCORD_LOG_FILE"
   
   if [[ -f "$DISCORD_LOG_FILE" && -s "$DISCORD_LOG_FILE" ]]; then
       local messages
       messages=$(cat "$DISCORD_LOG_FILE" | jq -R -s '.')
       curl -H "Content-Type: application/json" \
            -X POST \
            -d "{\"content\": ${messages}}" \
            "$DISCORD_WEBHOOK_URL"
   fi
}

echo "Executing binary log backup script inside the container..."
sudo docker exec vmangos-database /home/default/scripts/03-binary-log-backup.sh

if [[ $? -eq 0 ]]; then
   echo "Binary log backup script executed successfully."
   TIMESTAMP=$(date +%Y%m%d_%H%M%S)
   
   echo "Compressing the binary logs..."
   7z a "$BACKUP_DIR/binary_logs_$TIMESTAMP.7z" "$BACKUP_DIR/mysql-bin.*"
   
   if [[ $? -eq 0 ]]; then
       echo "Binary logs compressed successfully."
       
       echo "Removing uncompressed binary logs..."
       eval rm -f "$BACKUP_DIR/mysql-bin.*"
       
       if [[ $? -eq 0 ]]; then
           echo "Uncompressed binary logs cleaned up successfully."
           log_and_send_discord "Incremental binary logs backup completed successfully."
       else
           echo "Failed to clean up uncompressed binary logs."
           log_and_send_discord "Incremental binary logs backup failed during cleanup."
           exit 1
       fi
   else
       echo "Failed to compress binary logs."
       log_and_send_discord "Incremental binary logs backup failed during compression."
       exit 1
   fi
else
   echo "Failed to execute binary log backup script inside the container."
   log_and_send_discord "Incremental binary logs backup failed during the log copy."
   exit 1
fi
