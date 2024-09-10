FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

# Install required dependencies
RUN apt-get update -y && \
  apt-get install -y \
    libace-dev \
    libcurl4-openssl-dev \
    libmysqlclient-dev \
    libssl-dev \
    openssl \
    zlib1g-dev

# Create a group and user 'vmangos-realmd-user' with specific UID and GID 1001
RUN groupadd -r vmangos-realmd-user && \
    useradd -r -u 1001 -g vmangos-realmd-user -d /home/vmangos-realmd-user -s /bin/false vmangos-realmd-user

# Create necessary directories and set permissions
RUN mkdir -p /opt/vmangos && \
    chown -R vmangos-realmd-user:vmangos-realmd-user /opt/vmangos

# Copy the realmd binary into the appropriate directory
COPY ./vol/core/bin/realmd /opt/vmangos/bin/realmd

# Set executable permissions for the binaries
RUN chmod +x /opt/vmangos/bin/realmd && \
    chown -R vmangos-realmd-user:vmangos-realmd-user /opt/vmangos/bin

# Download the wait script and set permissions
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait /opt/wait
RUN chmod +x /opt/wait && \
    chown vmangos-realmd-user:vmangos-realmd-user /opt/wait

# Set the working directory
WORKDIR /opt/vmangos/bin

# Switch to the newly created user
USER vmangos-realmd-user

# Set the default command to run realmd with the configuration file
CMD /opt/wait && ./realmd -c ../etc/realmd.conf

