#!/bin/bash

echo "[YesilCMS]: Creating database..."
mariadb -u mangos mangos CREATE DATABASE [cms_db];;

echo "[YesilCMS]: Creating user..."
CREATE USER '[cms_user]'@'[host]' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD_YESILCMS';

echo "[YesilCMS]: Granting privileges for user..."

TODO
mariadb -u cms_user mangos GRANT ALL PRIVILEGES ON *.* TO 'mangos'@'%' IDENTIFIED BY 'mangos';
mariadb -u mangos mangos FLUSH PRIVILEGES;
mariadb -u mangos mangos GRANT ALL ON realmd.* TO mangos@'localhost' WITH GRANT OPTION;
mariadb -u mangos mangos GRANT ALL ON characters.* TO mangos@'localhost' WITH GRANT OPTION;
mariadb -u mangos mangos GRANT ALL ON mangos.* TO mangos@'localhost' WITH GRANT OPTION;
mariadb -u mangos mangos GRANT ALL ON logs.* TO mangos@'localhost' WITH GRANT OPTION;
mariadb -u mangos mangos FLUSH PRIVILEGES;

echo "[YesilCMS]: Database creation complete!"
