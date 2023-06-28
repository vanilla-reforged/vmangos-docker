#!/bin/bash

echo "[VMaNGOS]: Importing databases..."

echo "[VMaNGOS]: Importing world..."
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos < /src/github_database/$VMANGOS_WORLD_DATABASE.sql

echo "[VMaNGOS]: Importing logon..."
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD realmd < /src/github_core/sql/logon.sql 

echo "[VMaNGOS]: Importing logs..."
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD logs < /src/github_core/sql/logs.sql

echo "[VMaNGOS]: Importing characters..."
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD characters < /src/github_core/sql/characters.sql

echo "[VMaNGOS]: Importing database updates..."
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos < /src/github_core/sql/migrations/world_db_updates.sql
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD characters < /src/github_core/sql/migrations/characters_db_updates.sql
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD realmd < /src/github_core/sql/migrations/logon_db_updates.sql
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD logs < /src/github_core/sql/migrations/logs_db_updates.sql

echo "[VMaNGOS]: Upgrading mysql..."
mariadb-upgrade -u mangos -p$MYSQL_ROOT_PASSWORD

echo "[VMaNGOS]: Configuring default realm..."
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD -e \
  "INSERT INTO realmd.realmlist (name, address, port, icon, realmflags, timezone, allowedSecurityLevel, population, gamebuild_min, gamebuild_max, flag, realmbuilds) VALUES ('$VMANGOS_REALM_NAME', '$VMANGOS_REALM_IP', '$VMANGOS_REALM_PORT', '$VMANGOS_REALM_ICON', '$VMANGOS_REALM_FLAGS', '$VMANGOS_TIMEZONE', '$VMANGOS_ALLOWED_SECURITY_LEVEL', '$VMANGOS_POPULATION', '$VMANGOS_GAMEBUILD_MIN', '$VMANGOS_GAMEBUILD_MAX', '$VMANGOS_FLAG', '');"

echo "[VMaNGOS]: Database creation complete!"
