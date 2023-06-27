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

COPY ./src/extractors/mapextractor /src/extractors/mapextractor
COPY ./src/extractors/vmapextractor /src/extractors/vmapextractor
COPY ./src/extractors/vmap_assembler /src/extractors/vmap_assembler
COPY ./src/extractors/MoveMapGen /src/extractors/MoveMapGen
RUN chmod +x /src/extractors

WORKDIR /client_data

CMD
