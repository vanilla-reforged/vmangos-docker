FROM mariadb

RUN \
  apt-get update -y && \
  apt-get install -y \
  sudo 

COPY ./docker/yesilcms_database/generate-db.sh /

RUN chmod +x /generate-db.sh
