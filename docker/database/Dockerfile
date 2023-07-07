FROM mariadb:10

ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID
ARG VMANGOS_WORLD_DATABASE

RUN \
  mkdir -p /vol/backup && \
  mkdir -p /vol/core_github && \
  mkdir -p /vol/database_github

COPY ./docker/database/generate-db.sh /docker-entrypoint-initdb.d

RUN chmod +x /docker-entrypoint-initdb.d/generate-db.sh
RUN chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /var/lib/mysql
RUN chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /vol/backup
RUN chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /vol/core_github
RUN chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}/vol/database_github

USER ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}
