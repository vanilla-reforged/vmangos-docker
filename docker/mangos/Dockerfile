FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ARG VMANGOS_USER_ID
ARG VMANGOS_GROUP_ID

RUN \
  apt-get update -y && \
  apt-get install -y \
    libace-dev \
    libcurl4-openssl-dev \
    libmysqlclient-dev \
    libssl-dev \
    openssl \
    zlib1g-dev

RUN \
  mkdir -p /opt/vmangos && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /opt/vmangos

COPY ./vol/core/bin/mangosd /opt/vmangos/bin/mangosd

RUN chmod +x /opt/vmangos/bin

ADD \
  https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait \
  /opt/wait

RUN chmod +x /opt/wait

WORKDIR /opt/vmangos/bin

USER ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}

CMD /opt/wait && ./mangosd -c /opt/vmangos/etc/mangosd.conf
