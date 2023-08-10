#!/bin/bash

echo "[VMaNGOS]: Recreating world database..."
mariadb -u root -p$MYSQL_ROOT_PASSWORD DROP DATABASE mangos;
mariadb -u root -p$MYSQL_ROOT_PASSWORD CREATE DATABASE mangos DEFAULT CHARSET utf8 COLLATE utf8_general_ci;
mariadb -u root -p$MYSQL_ROOT_PASSWORD GRANT ALL PRIVILEGES ON *.* TO 'mangos'@'%' IDENTIFIED BY 'mangos';
mariadb -u root -p$MYSQL_ROOT_PASSWORD FLUSH PRIVILEGES;
mariadb -u root -p$MYSQL_ROOT_PASSWORD GRANT ALL ON mangos.* TO mangos@'localhost' WITH GRANT OPTION;
mariadb -u root -p$MYSQL_ROOT_PASSWORD FLUSH PRIVILEGES;

echo "[VMaNGOS]: Importing databases..."
echo "[VMaNGOS]: Importing world..."
mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < /vol/database_github/$VMANGOS_WORLD_DATABASE.sql

echo "[VMaNGOS]: Importing world db migrations..."
mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < /vol/core_github/sql/migrations/world_db_updates.sql

echo "[VMaNGOS]: Import finished."
