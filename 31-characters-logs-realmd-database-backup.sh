#!/bin/bash

# Load environment variables from .env-script
source "$(dirname "$0")/.env-script"

# Configuration
HOST_BACKUP_DIR="./vol/backup"  # Local backup directory on the host
CONTAINER_BACKUP_DIR="/vol/backup"  # Backup directory inside the Docker container
DB_USER="mangos"  # Database username
DB_PASS="$MYSQL_ROOT_PASSWORD"  # Database password sourced from .env-script
CONTAINER_NAME="vmangos-database"  # Docker container name
TIMESTAMP=$(date +%Y%m%d%H%M%S)  # Generate a timestamp for file naming
FULL_BACKUP_FILENAME="full_backup_${TIMESTAMP}.7z"  # The final .7z file name

# Function to send a message to Discord
send_discord_message() {
    local message=$1
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$message\"}" \
         "$DISCORD_WEBHOOK"
}

# Function to create a full SQL dump (daily)
create_full_backup() {
    echo "Creating full SQL dump inside the container..."

    # Dump specific databases: characters, logs, realmd
    docker exec $CONTAINER_NAME bash -c "mariadb-dump --user=$DB_USER --password=$DB_PASS --databases characters logs realmd > $CONTAINER_BACKUP_DIR/full_backup.sql"

    if [[ $? -eq 0 ]]; then
        echo "Full SQL dump created successfully inside the container."

        # Copy the SQL dump from the container to the host
        docker cp "$CONTAINER_NAME:$CONTAINER_BACKUP_DIR/full_backup.sql" "$HOST_BACKUP_DIR/"

        # Compress the SQL dump on the host with the timestamped name
        echo "Compressing full SQL dump on the host..."
        7z a "$HOST_BACKUP_DIR/$FULL_BACKUP_FILENAME" "$HOST_BACKUP_DIR/full_backup.sql"

        if [[ $? -eq 0 ]]; then
            echo "Full SQL dump compressed successfully on the host."
            send_discord_message "Daily SQL dump backup completed successfully as $FULL_BACKUP_FILENAME."
            # Remove the uncompressed SQL file
            rm -f "$HOST_BACKUP_DIR/full_backup.sql"
        else
            echo "Failed to compress full SQL dump on the host!"
            send_discord_message "Daily SQL dump backup failed during compression."
            exit 1
        fi
    else
        echo "Failed to create full SQL dump!"
        send_discord_message "Daily SQL dump backup failed."
        exit 1
    fi
}

# Main function to start the backup
create_full_backup
