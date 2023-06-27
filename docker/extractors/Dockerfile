FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN \
  apt-get update -y && \
  apt-get install -y \
    libace-dev \
    libcurl4-openssl-dev \
    libmysqlclient-dev \
    libssl-dev \
    openssl \
    zlib1g-dev

COPY ./vol/core/bin/mapextractor /vol/core/bin/mapextractor
COPY ./vol/core/bin/vmapextractor /vol/core/bin/vmapextractor
COPY ./vol/core/bin/vmap_assembler /vol/core/bin/vmap_assembler
COPY ./vol/core/bin/MoveMapGen /vol/core/bin/MoveMapGen
RUN chmod +x /opt/extract/bin

WORKDIR /client_data

CMD
