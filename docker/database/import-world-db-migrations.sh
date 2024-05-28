#!/bin/bash

echo "[VMaNGOS]: Importing migrations…"
sudo mariadb -u root -p$MYSQL_ROOT_PASSWORD -f mangos < /vol/core_github/sql/migrations/world_db_updates.sql
