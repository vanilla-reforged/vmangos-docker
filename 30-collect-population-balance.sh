#!/bin/bash

# Get variables defined in .env
source .env-script

# Database connection details
DB_USER="root"
DB_PASS="$MARIADB_ROOT_PASSWORD"
CHAR_DB="characters"
REALM_DB="realmd"
TABLE_NAME="characters"

# Output directory and file for population data
OUTPUT_DIR="vol/backup"
OUTPUT_FILE="$OUTPUT_DIR/population_data.csv"

# Ensure the output directory exists and is writable on the host
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Directory $OUTPUT_DIR does not exist on the host. Creating it now..."
    mkdir -p "$OUTPUT_DIR"
    chmod 755 "$OUTPUT_DIR"
fi

# Ensure the output file exists
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Creating population data file at $OUTPUT_FILE..."
    touch "$OUTPUT_FILE"
    chmod 644 "$OUTPUT_FILE"
fi

# SQL query to get the count of online Alliance and Horde characters
SQL_QUERY="SELECT
    COUNT(DISTINCT CASE WHEN c.race IN (1, 3, 4, 7) THEN c.account END) AS alliance_count,
    COUNT(DISTINCT CASE WHEN c.race IN (2, 5, 6, 8) THEN c.account END) AS horde_count
FROM ${CHAR_DB}.${TABLE_NAME} c
JOIN ${REALM_DB}.account a ON c.account = a.id
WHERE a.online = 1
AND c.guid = (SELECT MIN(c2.guid) FROM ${CHAR_DB}.${TABLE_NAME} c2 WHERE c2.account = c.account);"

# Get current timestamp
CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# Run the SQL query inside the MariaDB container and output the result
RESULT=$(docker exec -i vmangos-database mariadb -u $DB_USER -p$DB_PASS -sN -e "$SQL_QUERY")

# Debugging: Print the result to check if it is captured correctly
echo "DEBUG: Result from SQL query: '$RESULT'"

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
