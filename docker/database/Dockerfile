FROM mariadb

# Create the group and user 'vmangos-database-user' with specific UID and GID
RUN groupadd -r vmangos-database-user && \
    useradd -r -g vmangos-database-user -d /home/vmangos-database-user -s /bin/false -u 1001 vmangos-database-user

# Install required packages
RUN apt-get update -y && \
    apt-get install -y sudo && \
    mkdir -p /vol/backup /vol/core-github /vol/database-github && \
    chown -R vmangos-database-user:vmangos-database-user /vol/backup /vol/core-github /vol/database-github

# Switch to the newly created user
USER vmangos-database-user

# Set the working directory
WORKDIR /home/vmangos-database-user

# Default command
CMD ["mysqld"]
