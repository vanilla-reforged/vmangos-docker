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
    COUNT(DISTINCT CASE WHEN c.race IN (1, 3, 4, 7) THEN c.account END) AS alliance_count,
    COUNT(DISTINCT CASE WHEN c.race IN (2, 5, 6, 8) THEN c.account END) AS horde_count
FROM ${CHAR_DB}.${TABLE_NAME} c
JOIN ${REALM_DB}.account a ON c.account = a.id
WHERE a.online = 1
AND c.guid = (SELECT MIN(c2.guid) FROM ${CHAR_DB}.${TABLE_NAME} c2 WHERE c2.account = c.account);"

# Run the SQL query and output the result
mariadb -u $DB_USER -p$DB_PASS -sN -e "$SQL_QUERY"
