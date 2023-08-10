#!/bin/bash

echo "[VMaNGOS]: Recreating world database..."
mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "DROP DATABASE mangos;"
mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE mangos DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"
mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'mangos'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON mangos.* TO mangos@'localhost' WITH GRANT OPTION;"
mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

echo "[VMaNGOS]: Importing databases..."
echo "[VMaNGOS]: Importing world..."
mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < /vol/database_github/$VMANGOS_WORLD_DATABASE.sql

echo "[VMaNGOS]: Importing world db migrations..."
mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < /vol/core_github/sql/migrations/world_db_updates.sql

echo "[VMaNGOS]: Import finished."
