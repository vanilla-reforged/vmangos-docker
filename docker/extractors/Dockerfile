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

RUN \
  mkdir -p /vol/core && \
  mkdir -p /vol/client-data

RUN chmod +x /vol/core

WORKDIR /vol/client-data