#!/bin/bash

echo "[YesilCMS]: Creating database..."
mariadb -u root CREATE DATABASE [cms_db];;

echo "[YesilCMS]: Creating user..."
CREATE USER '[cms_user]'@'[host]' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD_YESILCMS';

echo "[YesilCMS]: Granting privileges for user..."

mariadb -u cms_user -p$MYSQL_ROOT_PASSWORD_YESILCMS cms_db GRANT ALL PRIVILEGES ON *.* TO 'mangos'@'%' IDENTIFIED BY 'mangos';
mariadb -u cms_user -p$MYSQL_ROOT_PASSWORD_YESILCMS cms_db FLUSH PRIVILEGES;
mariadb -u cms_user -p$MYSQL_ROOT_PASSWORD_YESILCMS cms_db GRANT ALL ON realmd.* TO mangos@'localhost' WITH GRANT OPTION;
mariadb -u cms_user -p$MYSQL_ROOT_PASSWORD_YESILCMS cms_db GRANT ALL ON characters.* TO mangos@'localhost' WITH GRANT OPTION;
mariadb -u cms_user -p$MYSQL_ROOT_PASSWORD_YESILCMS cms_db GRANT ALL ON mangos.* TO mangos@'localhost' WITH GRANT OPTION;
mariadb -u cms_user -p$MYSQL_ROOT_PASSWORD_YESILCMS cms_db GRANT ALL ON logs.* TO mangos@'localhost' WITH GRANT OPTION;
mariadb -u cms_user -p$MYSQL_ROOT_PASSWORD_YESILCMS cms_db FLUSH PRIVILEGES;

echo "[YesilCMS]: Database creation complete!"
