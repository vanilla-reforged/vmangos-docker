#!/bin/bash

  'mysqldump -h 127.0.0.1 -u root -p$MYSQL_ROOT_PASSWORD mangos > /backup/mangos.sql'
docker-compose exec -T vmangos_database sh -c \
  'mysqldump -h 127.0.0.1 -u root -p$MYSQL_ROOT_PASSWORD characters > /backup/characters.sql'
docker-compose exec -T vmangos_database sh -c \
  'mysqldump -h 127.0.0.1 -u root -p$MYSQL_ROOT_PASSWORD realmd > /backup/realmd.sql'
