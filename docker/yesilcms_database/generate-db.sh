#!/bin/bash

echo "[YesilCMS]: Creating database..."
mariadb -u root CREATE DATABASE [cms_db];;

echo "[YesilCMS]: Creating user..."
mariadb -u root -p$MYSQL_ROOT_PASSWORD_YESILCMS USER '[cms_user]'@'[host]' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD_YESILCMS';

echo "[YesilCMS]: Granting privileges for user..."

mariadb -u cms_user -p$MYSQL_ROOT_PASSWORD_YESILCMS cms_db GRANT USAGE ON *.* TO '[cms_user]'@'[localhost]';
mariadb -u cms_user -p$MYSQL_ROOT_PASSWORD_YESILCMS cms_db GRANT SELECT, EXECUTE, SHOW VIEW, ALTER, ALTER ROUTINE, CREATE, CREATE ROUTINE, CREATE TEMPORARY TABLES, CREATE VIEW, DELETE, DROP, EVENT, INDEX, INSERT, REFERENCES, TRIGGER, UPDATE, LOCK TABLES  ON [cms_db].* TO '[cms_user]'@'[host]';
mariadb -u cms_user -p$MYSQL_ROOT_PASSWORD_YESILCMS cms_db FLUSH PRIVILEGES;

echo "[YesilCMS]: Database creation complete!"
