FROM mariadb

ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID
ARG VMANGOS_WORLD_DATABASE

RUN \
     mkdir -p  /vol/backup 

COPY ./src/github_database/${VMANGOS_WORLD_DATABASE}.sql /src/github_database/${VMANGOS_WORLD_DATABASE}.sql
     
COPY ./src/github_core/sql/logon.sql /src/github_core/sql/logon.sql && \
     ./src/github_core/sql/logs.sql /src/github_core/sql/logs.sql && \
     ./src/github_core/sql/characters.sql /src/github_core/sql/characters.sql
     
COPY ./src/github_core/sql/migrations/world_db_updates.sql /src/github_core/sql/migrations/world_db_updates.sql && \
     ./src/github_core/sql/migrations/characters_db_updates.sql /src/github_core/sql/migrations/characters_db_updates.sql && \
     ./src/github_core/sql/migrations/logon_db_updates.sql /src/github_core/sql/migrations/logon_db_updates.sql && \
     ./src/github_core/sql/migrations/logs_db_updates.sql /src/github_core/sql/migrations/logs_db_updates.sql

COPY ./docker/database/generate-db-1.sql /docker-entrypoint-initdb.d && \
     ./docker/database/generate-db-2.sh /docker-entrypoint-initdb.d && \
     ./docker/database/regenerate-world-db.sql /sql/regenerate-world-db.sql
