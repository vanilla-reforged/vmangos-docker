FROM mariadb

ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID

COPY ./docker/database/generate-db-1.sql /docker-entrypoint-initdb.d
COPY ./docker/database/generate-db-2.sh /docker-entrypoint-initdb.d
COPY ./docker/database/regenerate-world-db.sql /sql/regenerate-world-db.sql
