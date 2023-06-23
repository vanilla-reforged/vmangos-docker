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

ARG TZ
ARG MYSQL_ROOT_PASSWORD
ARG VMANGOS_WORLD
ARG VMANGOS_REALM_NAME
ARG VMANGOS_REALM_IP
ARG VMANGOS_REALM_PORT
ARG VMANGOS_REALM_ICON
ARG VMANGOS_REALM_FLAGS
ARG VMANGOS_TIMEZONE
ARG VMANGOS_ALLOWED_SECURITY_LEVEL
ARG VMANGOS_POPULATION
ARG VMANGOS_GAMEBUILD_MIN
ARG VMANGOS_GAMEBUILD_MAX
ARG VMANGOS_FLAG
ARG VMANGOS_GROUP_ID
ARG VMANGOS_USER_ID
ARG VMANGOS_GIT_SOURCE_CORE
ARG VMANGOS_GIT_SOURCE_DATABASE
ARG DEBIAN_FRONTEND=noninteractive

ENV \
  VMANGOS_USER_ID=$VMANGOS_USER_ID \
  VMANGOS_GROUP_ID=$VMANGOS_GROUP_ID

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
#   libtbb-dev \
    openssl \
    p7zip-full \
    zlib1g-dev

RUN \
  ln -s /usr/bin/ccache /usr/local/bin/gcc && \
  ln -s /usr/bin/ccache /usr/local/bin/g++ && \
  ln -s /usr/bin/ccache /usr/local/bin/cc && \
  ln -s /usr/bin/ccache /usr/local/bin/c++

RUN \
  export ACE_ROOT=/usr/include/ace

RUN \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /opt && \
  mkdir -p /compiled_core && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /compiled_core && \
  mkdir -p /ccache && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /ccache && \
  mkdir -p /database && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /database

USER ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}

CMD \
  git clone -b $VMANGOS_GIT_SOURCE_CORE /opt/core && \
  git clone -b $VMANGOS_GIT_SOURCE_DATABASE /opt/database && \
  cd /opt/core/sql/migrations && \
  ./merge.sh && \
  mkdir /opt/core/build && \
  cd /opt/core/build && \
  cmake \
    -DCMAKE_INSTALL_PREFIX=/compiled_core ../ && \
  make -j $VMANGOS_THREADS && \
  make install && \
  mkdir /opt/compiled_core/data && \
  mkdir /opt/compiled_core/logs && \
  cp -r /opt/compiled_core/* /compiled_core && \
  cp -r /opt/database/* /database && \
  cd /database && 7z e $VMANGOS_WORLD.7z
