FROM ubuntu:20.04

RUN \
  apt-get update -y && \
  apt-get install -y \
    Nginx Full \
    php7.4 \
    php7.4-fpm \
    mariadb-server

RUN \
  sudo chown -R nginx:nginx /var/www/html && \
  sudo usermod -a -G nginx nginx && \
  sudo find /var/www/html -type f -exec chmod 644 {} \; && \
  sudo find /var/www/html -type d -exec chmod 755 {} \; && \
  composer update

COPY ./docker/yesilcms/generate-db.sh /docker-entrypoint-initdb.d

RUN chmod +x /docker-entrypoint-initdb.d/generate-db.sh
