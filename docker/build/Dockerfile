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

#compiler image settings git clone
ARG VMANGOS_GIT_SOURCE_CORE_BRANCH
ARG VMANGOS_GIT_SOURCE_CORE_URL
ARG VMANGOS_GIT_SOURCE_DATABASE_BRANCH
ARG VMANGOS_GIT_SOURCE_DATABASE_URL
#compiler image settings cmake
ARG VMANGOS_THREADS
ARG VMANGOS_DEBUG
ARG VMANGOS_MALLOC
ARG VMANGOS_CLIENT
ARG VMANGOS_EXTRACTORS
ARG VMANGOS_ANTICHEAT
ARG VMANGOS_SCRIPTS
ARG VMANGOS_LIBCURL
#compiler and database image settings world database name
ARG VMANGOS_WORLD_DATABASE
#compiler image settings
ARG TZ
ARG VMANGOS_GROUP_ID
ARG VMANGOS_USER_ID
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
  export ACE_ROOT=/usr/include/ace \
  export TBB_ROOT_DIR=/usr/include/tbb

RUN \
  mkdir -p /opt/core && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /opt && \
  mkdir -p /compiled_core && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /compiled_core && \
  mkdir -p /ccache && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /ccache && \
  mkdir -p /database && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /database

USER ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}

CMD \
  git clone -b "${VMANGOS_GIT_SOURCE_CORE_BRANCH} ${VMANGOS_GIT_SOURCE_CORE_URL}" /opt/core && \
  git clone -b "${VMANGOS_GIT_SOURCE_DATABASE_BRANCH} ${VMANGOS_GIT_SOURCE_DATABASE_URL}" /opt/database && \
  cd /opt/core/sql/migrations && \
  ./merge.sh && \
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
    -DCMAKE_INSTALL_PREFIX=/opt/vmangos ../ && \
  make -j ${VMANGOS_THREADS} && \
  make install && \
  make -j ${VMANGOS_THREADS} && \
  make install && \
  mkdir /opt/compiled_core/data && \
  mkdir /opt/compiled_core/logs && \
  cp -r /opt/compiled_core/* /compiled_core && \
  cp -r /opt/database/* /database && \
  cd /database && 7z e ${VMANGOS_WORLD_DATABASE}.7z
