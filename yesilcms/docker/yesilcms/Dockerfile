FROM php

ARG DEBIAN_FRONTEND=noninteractive
ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID

RUN \
  apt-get update -y && \
  apt-get install -y \
  php-gd \
  php-mysql \
  php8.0-soap \
  php8.0-gmp \
  php-redis

RUN chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /var/www/html

USER ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}

WORKDIR /var/www/html
