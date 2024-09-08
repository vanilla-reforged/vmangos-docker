#!/bin/bash

# Set the desired user and group ID
USER_ID=1001
GROUP_ID=1001
USERNAME=dockeruser

# Directory paths on the host
WORDPRESS_DIR="$(pwd)/var/www/html"
MYSQL_DIR="$(pwd)/var/lib/mysql"
TRAEFIK_DIR="$(pwd)/etc/traefik"

# Create the user with the specified USER_ID and GROUP_ID if it doesn't already exist
if ! id "$USERNAME" &>/dev/null; then
    sudo groupadd -g $GROUP_ID $USERNAME
    sudo useradd -u $USER_ID -g $GROUP_ID -m -s /bin/bash $USERNAME
    echo "User $USERNAME created with UID $USER_ID and GID $GROUP_ID."
else
    echo "User $USERNAME already exists."
fi

# Set the ownership and permissions
sudo chown -R $USER_ID:$GROUP_ID $WORDPRESS_DIR $MYSQL_DIR $TRAEFIK_DIR
sudo chmod -R 775 $WORDPRESS_DIR $MYSQL_DIR $TRAEFIK_DIR

echo "Directories created and permissions set."