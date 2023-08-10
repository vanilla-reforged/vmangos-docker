#!/bin/bash

echo "[VMaNGOS]: Recreating world database..."
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "DROP DATABASE mangos;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE mangos DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'mangos'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON mangos.* TO mangos@'localhost' WITH GRANT OPTION;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

echo "[VMaNGOS]: Importing databases..."
echo "[VMaNGOS]: Importing world..."
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < /vol/database_github/$VMANGOS_WORLD_DATABASE.sql

echo "[VMaNGOS]: Importing world db migrations..."
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < /vol/core_github/sql/migrations/world_db_updates.sql

echo "[VMaNGOS]: Import finished."
