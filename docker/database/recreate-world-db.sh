echo "[VMaNGOS]: Recreating world database..."
docker exec vmangos_database /bin/bash 'mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos DROP DATABASE mangos;'
docker exec vmangos_database /bin/bash 'mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos CREATE DATABASE mangos DEFAULT CHARSET utf8 COLLATE utf8_general_ci;'
docker exec vmangos_database /bin/bash 'mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos GRANT ALL PRIVILEGES ON *.* TO 'mangos'@'%' IDENTIFIED BY 'mangos';'
docker exec vmangos_database /bin/bash 'mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos FLUSH PRIVILEGES;'
docker exec vmangos_database /bin/bash 'mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos GRANT ALL ON mangos.* TO mangos@'localhost' WITH GRANT OPTION;'
docker exec vmangos_database /bin/bash 'mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos FLUSH PRIVILEGES;'

echo "[VMaNGOS]: Importing databases..."
echo "[VMaNGOS]: Importing world..."
docker exec vmangos_database /bin/bash 'mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos < /vol/database_github/$VMANGOS_WORLD_DATABASE.sql'

echo "[VMaNGOS]: Importing world db migrations..."
docker exec vmangos_database /bin/bash 'mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos < /vol/core_github/sql/migrations/world_db_updates.sql'

echo "[VMaNGOS]: Import finished."
