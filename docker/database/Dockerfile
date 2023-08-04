FROM mariadb

RUN \
  apt-get update -y && \
  apt-get install -y \
  sudo 

RUN \
  mkdir -p /vol/backup && \
  mkdir -p /vol/core_github && \
  mkdir -p /vol/database_github

COPY ./docker/database/generate-db.sh /
COPY ./docker/database/import-world-db-migrations.sh /

RUN chmod +x /generate-db.sh
RUN chmod +x /import-world-db-migrations.sh
