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

RUN chmod +x /vol/core

WORKDIR /vol/client_data
