#!/bin/bash

# Set the desired user and group ID
USER_ID=1001
GROUP_ID=1001
USERNAME=dockeruser

# Directory paths on the host corresponding to your Docker Compose bind mounts
DIRS=(
    "$(pwd)/../vol/backup"
    "$(pwd)/../vol/core-github"
    "$(pwd)/../vol/database-github"
    "$(pwd)/../vol/database"
    "$(pwd)/../vol/configuration"
    "$(pwd)/../vol/client-data-extracted"
    "$(pwd)/../vol/logs/realmd"
    "$(pwd)/../vol/logs/mangos"
    "$(pwd)/../vol/logs/mangos/honor"
)

# Create the user with the specified USER_ID and GROUP_ID if it doesn't already exist
if ! id -u "$USERNAME" &>/dev/null; then
    sudo groupadd -g $GROUP_ID $USERNAME
    sudo useradd -u $USER_ID -g $GROUP_ID -m -s /bin/bash $USERNAME
    echo "User $USERNAME created with UID $USER_ID and GID $GROUP_ID."
else
    echo "User $USERNAME already exists."
fi

# Set the ownership and permissions for each directory
for DIR in "${DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        sudo chown -R $USER_ID:$GROUP_ID "$DIR"
        sudo chmod -R 775 "$DIR"
    else
        echo "Directory $DIR does not exist, skipping."
    fi
done

echo "Directories ownership and permissions have been set."
