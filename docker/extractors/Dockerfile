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

ARG VMANGOS_GROUP_ID
ARG VMANGOS_USER_ID
ARG DEBIAN_FRONTEND=noninteractive

ENV \
  VMANGOS_USER_ID=$VMANGOS_USER_ID \
  VMANGOS_GROUP_ID=$VMANGOS_GROUP_ID

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
  mkdir -p /opt/extract && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /opt/extract && \
  mkdir -p /client_data && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /client_data && \
  mkdir -p /mmap_contrib && \
  chown -R ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID} /mmap_contrib

COPY ./volume/compiled_core/bin/mapextractor /opt/extract/bin/mapextractor
COPY ./volume/compiled_core/bin/vmapextractor /opt/extract/bin/vmapextractor
COPY ./volume/compiled_core/bin/vmap_assembler /opt/extract/bin/vmap_assembler
COPY ./volume/compiled_core/bin/MoveMapGen /opt/extract/bin/MoveMapGen
RUN chmod +x /opt/extract/bin

WORKDIR /client_data

USER ${VMANGOS_USER_ID}:${VMANGOS_GROUP_ID}

CMD /opt/extract/bin/mapextractor /client_data
