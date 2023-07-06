FROM mariadb:10

ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID
ARG VMANGOS_WORLD_DATABASE

RUN mkdir -p /vol/backup
RUN mkdir -p /vol/core_github

COPY ./docker/database/generate-db-1.sql /docker-entrypoint-initdb.d
COPY ./docker/database/generate-db-2.sh /docker-entrypoint-initdb.d
COPY ./docker/database/regenerate-world-db.sql /sql/regenerate-world-db.sql

RUN chmod +x /docker-entrypoint-initdb.d/generate-db-2.sh

USER ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}
