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

# Create necessary directories
RUN mkdir -p /opt/vmangos

# Copy the realmd binary into the appropriate directory
COPY ./vol/core/bin/realmd /opt/vmangos/bin/realmd

# Set executable permissions for the binaries
RUN chmod +x /opt/vmangos/bin/realmd

# Download the wait script and set permissions
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait /opt/wait
RUN chmod +x /opt/wait

# Set the working directory
WORKDIR /opt/vmangos/bin

# Switch to the default user (1000:1000)
USER 1000:1000

# Set the default command to run realmd with the configuration file
CMD /opt/wait && ./realmd -c ../etc/realmd.conf
