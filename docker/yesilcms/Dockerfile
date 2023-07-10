FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID

RUN \
  apt-get update -y && \
  apt-get install -y \
    nginx \
    composer \
    php7.4 \
    php7.4-fpm \
    mariadb-server

WORKDIR /var/www/html

RUN \
  chown -R ${VMANGOS_GROUP_ID} /var/www/html && \
  usermod -a -G ${VMANGOS_USER_ID} && \
  find /var/www/html -type f -exec chmod 644 {} \; && \
  find /var/www/html -type d -exec chmod 755 {} \; && \

USER ${VMANGOS_GROUP_ID}:${VMANGOS_USER_ID}

RUN composer update

COPY ./docker/yesilcms/generate-db.sh /docker-entrypoint-initdb.d

RUN chmod +x /docker-entrypoint-initdb.d/generate-db.sh
