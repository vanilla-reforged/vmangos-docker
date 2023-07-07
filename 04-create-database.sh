#!/bin/bash

echo "[VMaNGOS]: Connecting to container…"
docker exec -it vmangos_database /bin/bash

echo "[VMaNGOS]: Creating databases…"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS realmd DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS characters DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS mangos DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS logs DEFAULT CHARSET utf8 COLLATE utf8_general_ci;"

echo "[VMaNGOS]: Creating user…"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE USER 'mangos'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "SET PASSWORD FOR 'mangos'@'localhost' = PASSWORD('$MYSQL_ROOT_PASSWORD');"

echo "[VMaNGOS]: Granting privileges for user…"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'mangos'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON realmd.* TO mangos@'localhost' WITH GRANT OPTION;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON characters.* TO mangos@'localhost' WITH GRANT OPTION;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON mangos.* TO mangos@'localhost' WITH GRANT OPTION;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL ON logs.* TO mangos@'localhost' WITH GRANT OPTION;"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

echo "[VMaNGOS]: Importing databases…"
echo "[VMaNGOS]: Importing world…"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < /vol/database_github/$VMANGOS_WORLD_DATABASE.sql
echo "[VMaNGOS]: Importing logon…"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD realmd < /vol/core_github/sql/logon.sql
echo "[VMaNGOS]: Importing logs…"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD logs < /vol/core_github/sql/logs.sql
echo "[VMaNGOS]: Importing characters…"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD characters < /vol/core_github/sql/characters.sql
echo "[VMaNGOS]: Importing migrations…"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD mangos < /vol/core_github/sql/migrations/world_db_updates.sql
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD characters < /vol/core_github/sql/migrations/characters_db_updates.sql
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD realmd < /vol/core_github/sql/migrations/logon_db_updates.sql
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD logs < /vol/core_github/sql/migrations/logs_db_updates.sql

echo "[VMaNGOS]: Upgrading mysql…"
sudo mariadb-upgrade -u root -p$MYSQL_ROOT_PASSWORD

echo "[VMaNGOS]: Configuring default realm…"
mariadb -u root -p$MYSQL_ROOT_PASSWORD -e "INSERT INTO realmd.realmlist (name, address, port, icon, realmflags, timezone, allowedSecurityLevel, population, gamebuild_min, gamebuild_max, flag, realmbuilds) VALUES ('$VMANGOS_REALM_NAME', '$VMANGOS_REALM_IP', '$VMANGOS_REALM_PORT', '$VMANGOS_REALM_ICON', '$VMANGOS_REALM_FLAGS', '$VMANGOS_TIMEZONE', '$VMANGOS_ALLOWED_SECURITY_LEVEL', '$VMANGOS_POPULATION', '$VMANGOS_GAMEBUILD_MIN', '$VMANGOS_GAMEBUILD_MAX', '$VMANGOS_FLAG', '');"

echo "[VMaNGOS]: Database creation complete!"

echo "[VMaNGOS]: Disconnecting from container"
"exit"
