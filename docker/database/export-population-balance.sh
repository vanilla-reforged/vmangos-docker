#!/bin/bash

# Ensure the environment variable is loaded
export MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}

# Database connection details
DB_USER="root"
DB_PASS="$MYSQL_ROOT_PASSWORD"
DB_NAME="realmd"
TABLE_NAME="characters"

# SQL query to get the count of Alliance and Horde characters
SQL_QUERY="SELECT 
    SUM(race IN (1, 3, 4, 7)) AS alliance_count, 
    SUM(race IN (2, 5, 6, 8)) AS horde_count 
FROM $TABLE_NAME 
WHERE online = 1;"

# Run the SQL query and output the result
mariadb -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "$SQL_QUERY"
