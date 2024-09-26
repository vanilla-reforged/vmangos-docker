FROM mariadb:11.5.2

# Install sudo and other necessary packages
RUN apt-get update -y && \
    apt-get install -y sudo && \
    mkdir -p /vol/backup /vol/core-github /vol/database-github /etc/mysql/conf.d /vol/faction-balancer && \
    chown -R 1000:1000 /etc/mysql

# Set ownership to default user 1000:1000 if needed
# You can remove the next line if the default user already owns the volumes.
# chown -R 1000:1000 /vol/backup /vol/core-github /vol/database-github

# Copy the scripts into the container and make them executable
COPY 01-mangos-database-backup.sh /home/default/scripts/01-mangos-database-backup.sh
COPY 01-Population-Balance-Collect.sh /home/default/scripts/01-Population-Balance-Collect.sh
COPY 02-characters-logs-realmd-databases-backup.sh /home/default/scripts/02-characters-logs-realmd-databases-backup.sh
COPY 03-binary-log-backup.sh /home/default/scripts/03-binary-log-backup.sh

# Make the scripts executable
RUN chmod +x /home/default/scripts/*.sh

# Switch to default user (1000:1000)
USER 1000:1000

# Set the working directory
WORKDIR /home/default

# Default command
CMD ["mysqld"]
