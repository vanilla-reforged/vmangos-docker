FROM php-apache

ARG DEBIAN_FRONTEND=noninteractive

RUN \
  apt-get update -y && \
  apt-get install -y \
    mariadb-server

COPY ./docker/yesilcms/generate-db.sh /

RUN chmod +x /generate-db.sh

WORKDIR /var/www/html

CMD composer update
