FROM mariadb:11.5.2

# Install sudo and other necessary packages
RUN apt-get update -y && \
    apt-get install -y sudo && \
    mkdir -p /vol/backup /vol/core-github /vol/database-github /etc/mysql/conf.d /vol/faction-balancer

# Set ownership to default user 1000:1000 if needed, though likely not necessary
# You can remove the next line if the default user already owns the volumes.
# chown -R 1000:1000 /vol/backup /vol/core-github /vol/database-github /etc/mysql/conf.d

# Switch to default user 1000:1000 if not already set in the base image
USER 1000:1000

# Set the working directory
WORKDIR /home/default

# Default command
CMD ["mysqld"]