#!/bin/bash

# Define the backup directory and age threshold
BACKUP_DIR="./vol/backup"
AGE_DAYS=7

# Delete files older than the specified age
find "$BACKUP_DIR" -type f -mtime +$AGE_DAYS -exec rm -f {} +

echo "[Backup Cleanup]: Deleted files older than $AGE_DAYS days from $BACKUP_DIR."
