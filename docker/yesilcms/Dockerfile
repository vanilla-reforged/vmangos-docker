FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID

RUN \
  apt-get update -y && \
  apt-get install -y \
    Nginx Full \
    php7.4 \
    php7.4-fpm \
    MariaDB

RUN \
  sudo chown -R nginx:nginx /var/www/html && \
  sudo usermod -a -G nginx nginx && \
  sudo find /var/www/html -type f -exec chmod 644 {} \; && \
  sudo find /var/www/html -type d -exec chmod 755 {} \;



USER ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}


