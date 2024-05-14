FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN \
  apt-get update -y && \
  apt-get install -y \
    build-essential \
    ccache \
    cmake \
    git \
    libace-dev \
    libcurl4-openssl-dev \
    libmysqlclient-dev \
    libssl-dev \
    libtbb-dev \
    openssl \
    zlib1g-dev

RUN \
  ln -s /usr/bin/ccache /usr/local/bin/gcc && \
  ln -s /usr/bin/ccache /usr/local/bin/g++ && \
  ln -s /usr/bin/ccache /usr/local/bin/cc && \
  ln -s /usr/bin/ccache /usr/local/bin/c++

RUN \
  mkdir -p /vol/ccache && \
  mkdir -p /vol/core && \
  mkdir -p /vol/core_github

RUN \
  export ACE_ROOT=/usr/include/ace && \
  export TBB_ROOT_DIR=/usr/include/tbb

CMD \
  mkdir -p /vol/core_github/build && \
  cd /vol/core_github/build && \
  cmake \
    -DDEBUG=${VMANGOS_DEBUG} \
    -DUSE_STD_MALLOC=${VMANGOS_MALLOC} \
    -DSUPPORTED_CLIENT_BUILD=${VMANGOS_CLIENT} \
    -DUSE_EXTRACTORS=${VMANGOS_EXTRACTORS} \
    -DUSE_ANTICHEAT=${VMANGOS_ANTICHEAT} \
    -DSCRIPTS=${VMANGOS_SCRIPTS} \
    -DUSE_LIBCURL=${VMANGOS_LIBCURL} \
    -DCMAKE_INSTALL_PREFIX=/vol/core ../ && \
  make -j ${VMANGOS_THREADS} && \
  make install && \
  cp /vol/core/etc/mangosd.conf.dist /vol/core/etc/mangosd.conf && \
  cp /vol/core/etc/realmd.conf.dist /vol/core/etc/realmd.conf
