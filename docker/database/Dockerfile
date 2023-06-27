FROM mariadb

ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID

COPY ./src/github_database/${VMANGOS_WORLD_DATABASE}.sql to where && \
     ./src/github_core/sql/migrations world_db_updates.sql characters_db_updates.sql logon_db_updates.sql logs_db_updates.sql


     ./src/github_core/sql logon.sql logs.sql characters.sql

COPY ./docker/database/generate-db-1.sql /docker-entrypoint-initdb.d && \
     ./docker/database/generate-db-2.sh /docker-entrypoint-initdb.d && \
     ./docker/database/regenerate-world-db.sql /sql/regenerate-world-db.sql
