# vmangos-docker
# Based on Michael Serajnik's work https://sr.ht/~mser/

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

# ARG VMANGOS_GIT_SOURCE_CORE_BRANCH=development not yet implemented
ARG VMANGOS_GIT_SOURCE_CORE_URL
# ARG VMANGOS_GIT_SOURCE_DATABASE_BRANCH=master not yet implemented
ARG VMANGOS_GIT_SOURCE_DATABASE_URL
ARG CCACHE_DIR
ARG VMANGOS_THREADS
ARG VMANGOS_DEBUG
ARG VMANGOS_MALLOC
ARG VMANGOS_CLIENT
ARG VMANGOS_EXTRACTORS
ARG VMANGOS_ANTICHEAT
ARG VMANGOS_SCRIPTS
ARG VMANGOS_LIBCURL
ARG VMANGOS_WORLD_DATABASE

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
  mkdir -p /opt/core && \
  mkdir -p /opt/compiled_core && \
  mkdir -p /compiled_core && \
  mkdir -p /ccache && \
  mkdir -p /database

RUN \
  git clone ${VMANGOS_GIT_SOURCE_CORE_URL} /opt/core && \
  git clone ${VMANGOS_GIT_SOURCE_DATABASE_URL} /opt/database && \

RUN \
  cd /opt/core/sql/migrations && \
  ./merge.sh && \
  mkdir /database/sql &&\
  cp -r /opt/core/sql/* /database/sql &&\
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
