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
    zlib1g-dev \
    libreadline-dev

# Create a user and group 'vmangos-mangos-user' with UID and GID 1001
RUN groupadd -r vmangos-mangos-user && \
    useradd -r -u 1001 -g vmangos-mangos-user -d /home/vmangos-mangos-user -s /bin/false vmangos-mangos-user

# Create necessary directories and set permissions
RUN mkdir -p /opt/vmangos && \
    chown -R vmangos-mangos-user:vmangos-mangos-user /opt/vmangos

# Copy the mangosd binary into the appropriate directory
COPY ./vol/core/bin/mangosd /opt/vmangos/bin/mangosd

# Set executable permissions for the binaries
RUN chmod +x /opt/vmangos/bin/mangosd && \
    chown -R vmangos-mangos-user:vmangos-mangos-user /opt/vmangos/bin

# Download the wait script and set permissions
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait /opt/wait
RUN chmod +x /opt/wait && \
    chown vmangos-mangos-user:vmangos-mangos-user /opt/wait

# Set the working directory
WORKDIR /opt/vmangos/bin

# Switch to the newly created user
USER vmangos-mangos-user

# Set the default command to run mangosd with the configuration file
CMD /opt/wait && ./mangosd -c /opt/vmangos/etc/mangosd.conf
