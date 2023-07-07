FROM mariadb

RUN \
  apt-get update -y && \
  apt-get install -y \
  sudo 

RUN \
  mkdir -p /vol/backup && \
  mkdir -p /vol/core_github && \
  mkdir -p /vol/database_github

COPY ./docker/database/generate-db.sh /docker-entrypoint-initdb.d

RUN chmod +x /docker-entrypoint-initdb.d/generate-db.sh
