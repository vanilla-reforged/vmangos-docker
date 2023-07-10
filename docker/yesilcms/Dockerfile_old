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

RUN \
  useradd -s /bin/false nginx && \
  chown -R nginx /var/www/html && \
  usermod -a -G nginx nginx && \
  find /var/www/html -type f -exec chmod 644 {} \; && \
  find /var/www/html -type d -exec chmod 755 {} \;

USER nginx

RUN composer update --working-dir=/var/www/html
RUN composer install --working-dir=/var/www/html

COPY ./docker/yesilcms/generate-db.sh /

RUN chmod +x /generate-db.sh
