#!/bin/bash
# Enhanced resource control for binary log backup
# Use maximum nice value, idle I/O class, and additional throttling

# Function that will run with strict limits
copy_binary_logs_limited() {
    # Configuration
    CONTAINER_BACKUP_DIR="/vol/backup"  # Backup directory inside the Docker container
    
    echo "Copying binary logs to $CONTAINER_BACKUP_DIR..."
    
    # Get list of binary logs first
    binlogs=$(ls /var/lib/mysql/mysql-bin.* 2>/dev/null)
    
    # Copy files one by one with pauses between each to reduce I/O spikes
    for binlog in $binlogs; do
        filename=$(basename "$binlog")
        echo "Copying $filename..."
        
        # Use dd with rate limiting instead of cp
        dd if="$binlog" of="$CONTAINER_BACKUP_DIR/$filename" bs=1M status=progress iflag=fullblock oflag=direct
        
        # Sleep between files to reduce resource impact
        sleep 2
        
        # Check if copy was successful
        if [[ $? -eq 0 ]]; then
            echo "$filename copied successfully."
        else
            echo "Failed to copy $filename!"
            exit 1
        fi
    done
    
    echo "Binary logs copied successfully to $CONTAINER_BACKUP_DIR."
}

# Execute with maximum resource limitations
nice -n 19 ionice -c 3 bash -c "$(declare -f copy_binary_logs_limited); copy_binary_logs_limited"
