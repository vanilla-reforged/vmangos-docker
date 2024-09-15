#!/bin/bash

# Load environment variables
source .env-script

# Configuration
HOST_BACKUP_DIR="./vol/backup"  # Local backup directory on the host
CONTAINER_BACKUP_DIR="/vol/backup"  # Backup directory inside the Docker container
FULL_BACKUP_DIR="$HOST_BACKUP_DIR/full_$(date +%Y%m%d%H%M%S)"  # Directory for full backups on the host
INCREMENTAL_BACKUP_DIR="$HOST_BACKUP_DIR/incremental_$(date +%Y%m%d%H%M%S)"  # Directory for incremental backups on the host
S3_BUCKET="s3://your-s3-bucket-name"  # S3 bucket name
USE_S3=true  # Set to false if you do not want to use S3
DB_USER="mangos"  # Database username
DB_PASS="$MYSQL_ROOT_PASSWORD"  # Database password sourced from .env-script
CONTAINER_NAME="vmangos-database"  # Docker container name

# Interval Configuration
FULL_BACKUP_HOUR="00"  # Hour to perform full backup (e.g., "00" for midnight)
INCREMENTAL_BACKUP_INTERVAL_MINUTES=60  # Interval in minutes for incremental backups (e.g., 60 for hourly)
TRUNCATION_DAY="4"  # Day of the week to perform table truncation (1=Monday, ..., 7=Sunday)

# Get current day, hour, and minute
CURRENT_DAY=$(date +%u)
CURRENT_HOUR=$(date +%H)
CURRENT_MINUTE=$(date +%M)

# Function to create a full backup (daily)
create_full_backup() {
    echo "Creating full backup inside the container..."
    docker exec $CONTAINER_NAME bash -c "mariabackup --backup --target-dir=$CONTAINER_BACKUP_DIR --user=$DB_USER --password=$DB_PASS"
    if [[ $? -eq 0 ]]; then
        echo "Full backup created successfully inside the container."
        mkdir -p $FULL_BACKUP_DIR
        docker cp $CONTAINER_NAME:$CONTAINER_BACKUP_DIR/. $FULL_BACKUP_DIR
        # Compress the backup directory
        echo "Compressing full backup directory..."
        7z a "$FULL_BACKUP_DIR.7z" "$FULL_BACKUP_DIR"
        if [[ $? -eq 0 ]]; then
            echo "Backup directory compressed successfully."
            # Remove the uncompressed backup directory
            rm -rf "$FULL_BACKUP_DIR"
            if [[ "$USE_S3" == true ]]; then
                copy_to_s3 "$FULL_BACKUP_DIR.7z" || return 1
            fi
        else
            echo "Failed to compress backup directory!"
            exit 1
        fi
    else
        echo "Failed to create full backup!"
        exit 1
    fi
}

# Function to create an incremental backup (hourly or minutely)
create_incremental_backup() {
    echo "Creating incremental backup inside the container..."
    LATEST_FULL_BACKUP=$(ls -td $HOST_BACKUP_DIR/full_* | head -1)
    if [ -z "$LATEST_FULL_BACKUP" ]; then
        echo "No full backup found for incremental backup. Aborting."
        exit 1
    fi
    docker cp $LATEST_FULL_BACKUP/. $CONTAINER_NAME:$CONTAINER_BACKUP_DIR
    docker exec $CONTAINER_NAME bash -c "mariabackup --backup --target-dir=$CONTAINER_BACKUP_DIR --incremental-basedir=$CONTAINER_BACKUP_DIR --user=$DB_USER --password=$DB_PASS"
    if [[ $? -eq 0 ]]; then
        echo "Incremental backup created successfully inside the container."
        mkdir -p $INCREMENTAL_BACKUP_DIR
        docker cp $CONTAINER_NAME:$CONTAINER_BACKUP_DIR/. $INCREMENTAL_BACKUP_DIR
        # Compress the backup directory
        echo "Compressing incremental backup directory..."
        7z a "$INCREMENTAL_BACKUP_DIR.7z" "$INCREMENTAL_BACKUP_DIR"
        if [[ $? -eq 0 ]]; then
            echo "Backup directory compressed successfully."
            # Remove the uncompressed backup directory
            rm -rf "$INCREMENTAL_BACKUP_DIR"
            if [[ "$USE_S3" == true ]]; then
                copy_to_s3 "$INCREMENTAL_BACKUP_DIR.7z" || return 1
            fi
        else
            echo "Failed to compress backup directory!"
            exit 1
        fi
    else
        echo "Failed to create incremental backup!"
        exit 1
    fi
}

# Function to copy the backup file to S3
copy_to_s3() {
    local BACKUP_PATH=$1
    echo "Uploading $BACKUP_PATH to S3..."
    aws s3 cp "$BACKUP_PATH" "$S3_BUCKET"
    if [[ $? -eq 0 ]]; then
        echo "$BACKUP_PATH uploaded to S3 successfully."
        return 0
    else
        echo "Failed to upload $BACKUP_PATH to S3!"
        return 1
    fi
}

# Function to clean up backups older than 8 days
clean_up_old_backups() {
    echo "Cleaning up local backups older than 8 days..."
    find $HOST_BACKUP_DIR -type f -name "*.7z" -mtime +8 -exec rm -f {} \;
    echo "Old backups cleaned up successfully."
}

# Function to truncate specified tables
truncate_tables() {
    echo "Truncating specified tables..."
    tables_to_truncate=(
        "logs.instance_creature_kills"
        "logs.instance_custom_counters"
    )

    for table in "${tables_to_truncate[@]}"; do
        echo "Truncating table $table..."
        docker exec $CONTAINER_NAME mariadb -u $DB_USER -p"$DB_PASS" -e "TRUNCATE TABLE $table;"
        if [[ $? -eq 0 ]]; then
            echo "Table $table truncated successfully."
        else
            echo "Failed to truncate table $table!"
            exit 1
        fi
    done
    echo "All specified tables truncated successfully."
}

# Main script logic to decide between full and incremental backups and truncation
if [[ "$CURRENT_HOUR" == "$FULL_BACKUP_HOUR" && "$CURRENT_MINUTE" == "00" ]]; then
    create_full_backup
    if [[ "$CURRENT_DAY" == "$TRUNCATION_DAY" ]]; then
        truncate_tables
    fi
elif (( $((10#$CURRENT_MINUTE)) % $INCREMENTAL_BACKUP_INTERVAL_MINUTES == 0 )); then
    create_incremental_backup
fi

# Clean up old backups if not using S3 or if S3 operation succeeds
if [[ "$USE_S3" == false || $? -eq 0 ]]; then
    clean_up_old_backups
fi

exit 0
