FROM php-apache

ARG DEBIAN_FRONTEND=noninteractive
ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID

RUN \
  apt-get update -y && \
  apt-get install -y \
    mariadb-server

COPY ./docker/yesilcms/generate-db.sh /

RUN chmod +x /generate-db.sh

WORKDIR /var/www/html

USER ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}

CMD composer update
