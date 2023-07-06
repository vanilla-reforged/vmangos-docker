#!/bin/bash

# Get variables defined in .env

source .env

# Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

# Start

echo "[VMaNGOS]: Removing old target directories..."
rm -r ./vol/core_github
rm -r ./vol/database_github

echo "[VMaNGOS]: Cloning github repositories..."
git clone $VMANGOS_GIT_SOURCE_CORE_URL ./vol/core_github/
git clone $VMANGOS_GIT_SOURCE_DATABASE_URL ./vol/database_github/

echo "[VMaNGOS]: Cloning github repositories finished."
echo "[VMaNGOS]: Extracting VMaNGOS world database with 7zip..."
cd ./vol/database_github
7z e $VMANGOS_WORLD_DATABASE.7z
cd "$repository_path"

echo "[VMaNGOS]: Merging VMaNGOS core migrations..."
cd ./vol/core_github/sql/migrations
./merge.sh
cd "$repository_path"

echo "[VMaNGOS]: VMaNGOS data prepared."
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
