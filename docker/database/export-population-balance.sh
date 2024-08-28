#!/bin/bash

# Ensure the environment variable is loaded
export MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}

# Database connection details
DB_USER="root"
DB_PASS="$MYSQL_ROOT_PASSWORD"
CHAR_DB="characters"
REALM_DB="realmd"
TABLE_NAME="characters"

# SQL query to get the count of online Alliance and Horde characters by joining `characters.characters` and `realmd.account`
SQL_QUERY="SELECT 
    IFNULL(SUM(c.race IN (1, 3, 4, 7)), 0) AS alliance_count, 
    IFNULL(SUM(c.race IN (2, 5, 6, 8)), 0) AS horde_count 
FROM ${CHAR_DB}.${TABLE_NAME} c 
JOIN ${REALM_DB}.account a ON c.account = a.id
WHERE a.online = 1;"

# Run the SQL query and output the result
mariadb -u $DB_USER -p$DB_PASS -sN -e "$SQL_QUERY"
