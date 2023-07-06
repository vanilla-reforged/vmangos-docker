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
  mkdir -p /opt/yesilcms && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /opt/yesilcms

# RUN chmod +x /opt/vmangos/bin

ADD \
  https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait \
  /opt/wait

RUN chmod +x /opt/wait

#WORKDIR /opt/vmangos/bin

USER ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}

CMD /opt/wait &&     #./realmd -c ../etc/realmd.conf
