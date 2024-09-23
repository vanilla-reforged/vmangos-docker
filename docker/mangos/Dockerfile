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

# Create necessary directories
RUN mkdir -p /opt/vmangos

# Copy the mangosd binary into the appropriate directory
COPY ./vol/core/bin/mangosd /opt/vmangos/bin/mangosd

# Set executable permissions for the binaries
RUN chmod +x /opt/vmangos/bin/mangosd

# Download the wait script and set permissions
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait /opt/wait
RUN chmod +x /opt/wait

# Copy the entrypoint script into the image
COPY docker/mangos/entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# Set the working directory
WORKDIR /opt/vmangos/bin

# Switch to the default user (1000:1000)
USER 1000:1000

# Set the entrypoint
ENTRYPOINT ["/opt/entrypoint.sh"]
