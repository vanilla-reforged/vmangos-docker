FROM webdevops/php-apache

ARG DEBIAN_FRONTEND=noninteractive

RUN \
  apt-get update -y && \
  apt-get install -y \
    mariadb-server

RUN chmod +x /generate-db.sh

WORKDIR /var/www/html

CMD composer update
