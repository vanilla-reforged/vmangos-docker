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
    p7zip-full \
    zlib1g-dev

RUN \
  ln -s /usr/bin/ccache /usr/local/bin/gcc && \
  ln -s /usr/bin/ccache /usr/local/bin/g++ && \
  ln -s /usr/bin/ccache /usr/local/bin/cc && \
  ln -s /usr/bin/ccache /usr/local/bin/c++

RUN \
  export ACE_ROOT=/usr/include/ace && \
  export TBB_ROOT_DIR=/usr/include/tbb

RUN \
  mkdir -p /src/github_core && \
  mkdir -p /vol/ccache && \
  mkdir -p /vol/core

RUN \
  git clone ${VMANGOS_GIT_SOURCE_CORE_URL} /opt/core && \
  git clone ${VMANGOS_GIT_SOURCE_DATABASE_URL} /opt/database

CMD \
  cd /opt/core/sql/migrations && \
  ./merge.sh && \
  cp -r /opt/core/* /core &&\
  mkdir /opt/core/build && \
  cd /opt/core/build && \
  cmake \
    -DDEBUG=${VMANGOS_DEBUG} \
    -DUSE_STD_MALLOC=${VMANGOS_MALLOC} \
    -DSUPPORTED_CLIENT_BUILD=${VMANGOS_CLIENT} \
    -DUSE_EXTRACTORS=${VMANGOS_EXTRACTORS} \
    -DUSE_ANTICHEAT=${VMANGOS_ANTICHEAT} \
    -DSCRIPTS=${VMANGOS_SCRIPTS} \
    -DUSE_LIBCURL=${VMANGOS_LIBCURL} \
    -DCMAKE_INSTALL_PREFIX=/opt/compiled_core ../ && \
  make -j ${VMANGOS_THREADS} && \
  make install && \
  make -j ${VMANGOS_THREADS} && \
  make install && \
  mkdir /opt/compiled_core/data && \
  mkdir /opt/compiled_core/logs && \
  cp -r /opt/compiled_core/* /compiled_core && \
  cp -r /opt/database/* /database && \
  cd /database && 7z e ${VMANGOS_WORLD_DATABASE}.7z
