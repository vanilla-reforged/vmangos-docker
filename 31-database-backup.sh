#!/bin/bash

# Load environment variables
source .env-script

# Configuration
HOST_BACKUP_DIR="./vol/backup"  # Local backup directory on the host
CONTAINER_BACKUP_DIR="/vol/backup"  # Backup directory inside the Docker container
FULL_BACKUP_DIR="$HOST_BACKUP_DIR/full_$(date +%Y%m%d%H%M%S)"  # Directory for full backups on the host
INCREMENTAL_BACKUP_DIR="$HOST_BACKUP_DIR/incremental_$(date +%Y%m%d%H%M%S)"  # Directory for incremental backups on the host
S3_BUCKET="s3://your-s3-bucket-name"  # S3 bucket name
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
    # Run the backup inside the container, directing output to the container's backup directory
    docker exec $CONTAINER_NAME bash -c "mariabackup --backup --target-dir=$CONTAINER_BACKUP_DIR --user=$DB_USER --password=$DB_PASS"
    if [[ $? -eq 0 ]]; then
        echo "Full backup created successfully inside the container."
        # Copy the full backup from the container to the host backup directory
        mkdir -p $FULL_BACKUP_DIR
        docker cp $CONTAINER_NAME:$CONTAINER_BACKUP_DIR/. $FULL_BACKUP_DIR
        copy_to_s3 $FULL_BACKUP_DIR
    else
        echo "Failed to create full backup!"
        exit 1
    fi
}

# Function to create an incremental backup (hourly or minutely)
create_incremental_backup() {
    echo "Creating incremental backup inside the container..."
    # Find the latest full backup directory on the host to use as the base for incremental backups
    LATEST_FULL_BACKUP=$(ls -td $HOST_BACKUP_DIR/full_* | head -1)
    if [ -z "$LATEST_FULL_BACKUP" ]; then
        echo "No full backup found for incremental backup. Aborting."
        exit 1
    fi
    # Copy the latest full backup to the container's backup directory for reference
    docker cp $LATEST_FULL_BACKUP/. $CONTAINER_NAME:$CONTAINER_BACKUP_DIR
    # Run the incremental backup inside the container
    docker exec $CONTAINER_NAME bash -c "mariabackup --backup --target-dir=$CONTAINER_BACKUP_DIR --incremental-basedir=$CONTAINER_BACKUP_DIR --user=$DB_USER --password=$DB_PASS"
    if [[ $? -eq 0 ]]; then
        echo "Incremental backup created successfully inside the container."
        # Copy the incremental backup from the container to the host backup directory
        mkdir -p $INCREMENTAL_BACKUP_DIR
        docker cp $CONTAINER_NAME:$CONTAINER_BACKUP_DIR/. $INCREMENTAL_BACKUP_DIR
        copy_to_s3 $INCREMENTAL_BACKUP_DIR
    else
        echo "Failed to create incremental backup!"
        exit 1
    fi
}

# Function to copy the backup file to S3
copy_to_s3() {
    local BACKUP_PATH=$1
    echo "Uploading $BACKUP_PATH to S3..."
    aws s3 cp --recursive $BACKUP_PATH $S3_BUCKET
    if [[ $? -eq 0 ]]; then
        echo "$BACKUP_PATH uploaded to S3 successfully."
    else
        echo "Failed to upload $BACKUP_PATH to S3!"
        exit 1
    fi
}

# Function to clean up backups older than 8 days
clean_up_old_backups() {
    echo "Cleaning up local backups older than 8 days..."
    find $HOST_BACKUP_DIR -type d -mtime +8 -exec rm -rf {} \;
    echo "Old backups cleaned up successfully."
}

# Function to truncate specified tables
truncate_tables() {
    echo "Truncating specified tables..."
    # Define the tables to truncate
    tables_to_truncate=(
        "logs.instance_creature_kills"
        "logs.instance_custom_counters"
        # Add other tables as needed
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
    # It's time for a full backup
    create_full_backup
    # Check if today is the truncation day
    if [[ "$CURRENT_DAY" == "$TRUNCATION_DAY" ]]; then
        # After successful full backup, truncate tables
        truncate_tables
    fi
elif (( $((10#$CURRENT_MINUTE)) % $INCREMENTAL_BACKUP_INTERVAL_MINUTES == 0 )); then
    # Create an incremental backup based on the configured minute interval
    create_incremental_backup
fi

# Clean up old backups
clean_up_old_backups

exit 0
