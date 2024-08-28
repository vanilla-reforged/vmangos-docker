#!/bin/bash

# Define the MariaDB container name
MARIADB_CONTAINER="vmangos_database"  # Ensure this is the correct container name

# Output directory and file for population data
OUTPUT_DIR="./population"
OUTPUT_FILE="$OUTPUT_DIR/population_data.csv"

# Ensure the output directory exists and is writable
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Directory $OUTPUT_DIR does not exist. Creating it now..."
    mkdir -p "$OUTPUT_DIR"
    chmod 755 "$OUTPUT_DIR"
fi

# Ensure the output file exists
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Creating population data file at $OUTPUT_FILE..."
    touch "$OUTPUT_FILE"
    chmod 644 "$OUTPUT_FILE"
fi

# Get current timestamp
CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# Run the population balance script inside the MariaDB container
RESULT=$(docker exec $MARIADB_CONTAINER /export-population-balance.sh)

# Debugging: Print the result to check if it is captured correctly
echo "DEBUG: Result from export-population-balance.sh: '$RESULT'"

# Read the results into variables, trimming any whitespace
ALLIANCE_COUNT=$(echo "$RESULT" | awk '{print $1}')
HORDE_COUNT=$(echo "$RESULT" | awk '{print $2}')

# Debugging: Print the extracted values to check for any issues
echo "DEBUG: Extracted Alliance Count: '$ALLIANCE_COUNT', Horde Count: '$HORDE_COUNT'"

# Check if the variables are valid integers
if ! [[ "$ALLIANCE_COUNT" =~ ^[0-9]+$ ]] || ! [[ "$HORDE_COUNT" =~ ^[0-9]+$ ]]; then
    echo "Error fetching population data. Please check the script or database connection. Output: $RESULT"
    exit 1
fi

# Append the result to the output file
echo "$CURRENT_TIME,$ALLIANCE_COUNT,$HORDE_COUNT" >> "$OUTPUT_FILE"

echo "Population data collected at $CURRENT_TIME: Alliance=$ALLIANCE_COUNT, Horde=$HORDE_COUNT"
