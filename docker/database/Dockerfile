FROM mariadb:11.5.2

# Create the group and user 'vmangos-database-user'
RUN groupadd -r vmangos-database-user && \
    useradd -r -g vmangos-database-user -d /home/vmangos-database-user -s /bin/false -u 1001 vmangos-database-user && \
    apt-get update -y && \
    apt-get install -y sudo && \
    mkdir -p /vol/backup /vol/core-github /vol/database-github /etc/mysql/conf.d && \
    chown -R vmangos-database-user:vmangos-database-user /vol/backup /vol/core-github /vol/database-github /etc/mysql/conf.d && \
    echo "vmangos-database-user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to the newly created user
USER vmangos-database-user

# Set the working directory
WORKDIR /home/vmangos-database-user

# Default command
CMD ["mysqld"]
