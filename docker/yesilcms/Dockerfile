FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
#ARG VMANGOS_USER_ID
#ARG VMANGOS_GROUP_ID

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
  useradd -s /bin/false nginx && \
  chown -R nginx:nginx /var/www/html && \
  usermod -a -G nginx nginx && \
  find /var/www/html -type f -exec chmod 644 {} \; && \
  find /var/www/html -type d -exec chmod 755 {} \;

USER nginx

RUN composer update

COPY ./docker/yesilcms/generate-db.sh /docker-entrypoint-initdb.d

RUN chmod +x /docker-entrypoint-initdb.d/generate-db.sh
