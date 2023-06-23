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

FROM mariadb

ARG \ 
   VMANGOS_USER_ID \
   VMANGOS_GROUP_ID \
   VMANGOS_DATABASE_ENGINE \
   VMANGOS_WORLD_DATABASE \
   MYSQL_ROOT_PASSWORD \
   VMANGOS_REALM_NAME \
   VMANGOS_REALM_IP \
   VMANGOS_REALM_PORT \
   VMANGOS_REALM_ICON \
   VMANGOS_REALM_FLAGS \
   VMANGOS_TIMEZONE \
   VMANGOS_ALLOWED_SECURITY_LEVEL \
   VMANGOS_POPULATION \
   VMANGOS_GAMEBUILD_MIN \
   VMANGOS_GAMEBUILD_MAX \
   VMANGOS_FLAG

RUN \
  mkdir -p /backup && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /backup

USER ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}

CMD \
mariadb-shell  && \
CREATE DATABASE IF NOT EXISTS realmd DEFAULT CHARSET utf8 COLLATE utf8_general_ci;  && \
CREATE DATABASE IF NOT EXISTS characters DEFAULT CHARSET utf8 COLLATE utf8_general_ci;  && \
CREATE DATABASE IF NOT EXISTS mangos DEFAULT CHARSET utf8 COLLATE utf8_general_ci;  && \
CREATE DATABASE IF NOT EXISTS logs DEFAULT CHARSET utf8 COLLATE utf8_general_ci;  && \
CREATE USER 'mangos'@'localhost' IDENTIFIED BY 'mangos';  && \
SET PASSWORD FOR 'mangos'@'localhost' = PASSWORD('${MYSQL_ROOT_PASSWORD}');  && \
GRANT ALL PRIVILEGES ON *.* TO 'mangos'@'%' IDENTIFIED BY 'mangos';  && \
FLUSH PRIVILEGES;  && \
GRANT ALL ON realmd.* TO mangos@'localhost' WITH GRANT OPTION;  && \
GRANT ALL ON characters.* TO mangos@'localhost' WITH GRANT OPTION;  && \
GRANT ALL ON mangos.* TO mangos@'localhost' WITH GRANT OPTION;  && \
GRANT ALL ON logs.* TO mangos@'localhost' WITH GRANT OPTION;  && \
FLUSH PRIVILEGES;  && \
exit  && \

mariadb -u mangos -p ${MYSQL_ROOT_PASSWORD} realmd < /opt/database/logon.sql
mariadb -u mangos -p ${MYSQL_ROOT_PASSWORD} logs < /opt/database/logs.sql
mariadb -u mangos -p ${MYSQL_ROOT_PASSWORD} characters < /opt/database/characters.sql
mariadb -u mangos -p ${MYSQL_ROOT_PASSWORD} mangos < /opt/database/${VMANGOS_WORLD_DATABASE}.sql
[ -e /opt/vmangos/sql/migrations/world_db_updates.sql ] && \
  mariadb -u mangos -p ${MYSQL_ROOT_PASSWORD} mangos < /opt/vmangos/sql/migrations/world_db_updates.sql
[ -e /opt/vmangos/sql/migrations/characters_db_updates.sql ] && \
  mariadb -u mangos -p ${MYSQL_ROOT_PASSWORD} characters < /opt/vmangos/sql/migrations/characters_db_updates.sql
[ -e /opt/vmangos/sql/migrations/logon_db_updates.sql ] && \
  mariadb -u mangos -p ${MYSQL_ROOT_PASSWORD} realmd < /opt/vmangos/sql/migrations/logon_db_updates.sql
[ -e /opt/vmangos/sql/migrations/logs_db_updates.sql ] && \
  mariadb -u mangos -p ${MYSQL_ROOT_PASSWORD} logs < /opt/vmangos/sql/migrations/logs_db_updates.sql
mariadb-upgrade -u mangos -p ${MYSQL_ROOT_PASSWORD}
mariadb -u mangos -p ${MYSQL_ROOT_PASSWORD} -e \
  "INSERT INTO realmd.realmlist (name, address, port, icon, realmflags, timezone, allowedSecurityLevel, population, gamebuild_min, gamebuild_max, flag, realmbuilds) VALUES ('$VMANGOS_REALM_NAME', '$VMANGOS_REALM_IP', '$VMANGOS_REALM_PORT', '$VMANGOS_REALM_ICON', '$VMANGOS_REALM_FLAGS', '$VMANGOS_TIMEZONE', '$VMANGOS_ALLOWED_SECURITY_LEVEL', '$VMANGOS_POPULATION', '$VMANGOS_GAMEBUILD_MIN', '$VMANGOS_GAMEBUILD_MAX', '$VMANGOS_FLAG', '');"



