#!/bin/sh

# vmangos-docker
# Copyright (C) 2021-present  Michael Serajnik  https://sr.ht/~mser/

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#!/bin/bash
echo "[VMaNGOS]: Importing databases..."

echo "[VMaNGOS]: Importing logon..."
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD realmd < /opt/core/sql/logon.sql

echo "[VMaNGOS]: Importing logs..."
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD logs < /opt/core/sql/logs.sql

echo "[VMaNGOS]: Importing characters..."
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD characters < /opt/core/sql/characters.sql

echo "[VMaNGOS]: Importing world..."
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos < /opt/core/sql/$VMANGOS_WORLD.sql

echo "[VMaNGOS]: Importing database updates..."
[ -e /opt/core/sql/migrations/world_db_updates.sql ]
  mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos < /opt/core/sql/migrations/world_db_updates.sql
[ -e /opt/core/sql/migrations/characters_db_updates.sql ]
  mariadb -u mangos -p$MYSQL_ROOT_PASSWORD characters < /opt/core/sql/migrations/characters_db_updates.sql
[ -e /opt/core/sql/migrations/logon_db_updates.sql ]
  mariadb -u mangos -p$MYSQL_ROOT_PASSWORD realmd < /opt/core/sql/migrations/logon_db_updates.sql
[ -e /opt/core/sql/migrations/logs_db_updates.sql ]
  mariadb -u mangos -p$MYSQL_ROOT_PASSWORD logs < /opt/core/sql/migrations/logs_db_updates.sql

echo "[VMaNGOS]: Upgrading mysql..."
mariadb-upgrade -u mangos -p$MYSQL_ROOT_PASSWORD

echo "[VMaNGOS]: Configuring default realm..."
mariadb -u mangos -p$MYSQL_ROOT_PASSWORD -e \
  "INSERT INTO realmd.realmlist (name, address, port, icon, realmflags, timezone, allowedSecurityLevel, population, gamebuild_min, gamebuild_max, flag, realmbuilds) VALUES ('$VMANGOS_REALM_NAME', '$VMANGOS_REALM_IP', '$VMANGOS_REALM_PORT', '$VMANGOS_REALM_ICON', '$VMANGOS_REALM_FLAGS', '$VMANGOS_TIMEZONE', '$VMANGOS_ALLOWED_SECURITY_LEVEL', '$VMANGOS_POPULATION', '$VMANGOS_GAMEBUILD_MIN', '$VMANGOS_GAMEBUILD_MAX', '$VMANGOS_FLAG', '');"

echo "[VMaNGOS]: Database creation complete!"
