#!/bin/sh

#Get variables defined in .env

source .env

#Handle script call from other directory

get_script_path() {
  [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
repository_path=$(dirname "$(get_script_path "$0")")
cd "$repository_path"

repository_path=$(dirname "$(get_script_path "$0")")

cd "$repository_path"

echo "[VMaNGOS]: Importing database updates..."
[ -e /opt/core/sql/migrations/world_db_updates.sql ]
  mariadb -u mangos -p$MYSQL_ROOT_PASSWORD mangos < /src/github_core/sql/migrations/world_db_updates.sql
[ -e /opt/core/sql/migrations/characters_db_updates.sql ]
  mariadb -u mangos -p$MYSQL_ROOT_PASSWORD characters < /src/github_core/sql/migrations/characters_db_updates.sql
[ -e /opt/core/sql/migrations/logon_db_updates.sql ]
  mariadb -u mangos -p$MYSQL_ROOT_PASSWORD realmd < /src/github_core/sql/migrations/logon_db_updates.sql
[ -e /opt/core/sql/migrations/logs_db_updates.sql ]
  mariadb -u mangos -p$MYSQL_ROOT_PASSWORD logs < /src/github_core/sql/migrations/logs_db_updates.sql
