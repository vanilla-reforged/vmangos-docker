#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Get variables defined in .env-script
source ./../../.env-script  # Correctly load .env-script from the project root using $DOCKER_DIRECTORY

# This script installs Docker, Docker Compose, 7zip, jq, and sets up ufw-docker on an Ubuntu system

# Step 1: Update the package index
echo "Updating package index..."
apt-get update -y

# Step 2: Install required packages for Docker installation
echo "Installing required packages..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Step 3: Add Docker’s official GPG key
echo "Adding Docker's official GPG key..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Step 4: Set up the Docker repository
echo "Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Step 5: Update the package index again
echo "Updating package index again..."
apt-get update -y

# Step 6: Install Docker Engine, CLI, Containerd, and Docker Compose
echo "Installing Docker Engine and Docker Compose..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Step 7: Verify Docker installation
echo "Verifying Docker installation..."
docker --version

# Step 8: Verify Docker Compose installation
echo "Verifying Docker Compose installation..."
docker compose version

# Step 9: Install 7zip
echo "Installing 7zip..."
apt-get install -y p7zip-full

# Step 10: Revoke the original modification and apply new UFW configuration

echo "Reverting any previous modifications and applying UFW configuration..."

# Revert changes to Docker and UFW configurations
sed -i '/--iptables=false/d' /etc/docker/daemon.json
sed -i '/FORWARD/d' /etc/ufw/after.rules
systemctl restart docker

# Modify the UFW configuration file to add Docker rules
tee -a /etc/ufw/after.rules > /dev/null <<EOF

# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:ufw-docker-logging-deny - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw-user-forward

-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

-A DOCKER-USER -p udp -m udp --sport 53 --dport 1024:65535 -j RETURN

-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 192.168.0.0/16
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -p udp -m udp --dport 0:32767 -d 172.16.0.0/12

-A DOCKER-USER -j RETURN

-A ufw-docker-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A ufw-docker-logging-deny -j DROP

COMMIT
# END UFW AND DOCKER
EOF

# Restart UFW and enable it before rebooting
systemctl restart ufw
ufw enable

# Clean up temporary files
rm -rf ./ufw-docker

# Step 11: Notify the user about Docker usage
echo "Installation complete! Note: Since you are not added to the Docker group, you will need to use 'sudo' when running Docker commands."

# Step 12: Check if jq is installed; if not, attempt to install it
install_jq() {
  if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Attempting to install jq..."
    if [ -x "$(command -v apt-get)" ]; then
      apt-get update && apt-get install -y jq
    elif [ -x "$(command -v yum)" ]; then
      yum install -y jq
    elif [ -x "$(command -v dnf)" ]; then
      dnf install -y jq
    elif [ -x "$(command -v brew)" ]; then
      brew install jq
    else
      echo "Error: Could not determine package manager or install jq. Please install jq manually."
      exit 1
    fi

    if ! command -v jq &> /dev/null; then
      echo "Error: jq installation failed. Please install jq manually."
      exit 1
    else
      echo "jq successfully installed."
    fi
  else
    echo "jq is already installed. Skipping installation."
  fi
}

# Install jq if not already installed
install_jq

# Step 13: Configure sudoers for Docker commands

echo "Configuring sudoers for Docker commands for user '$LOCAL_USER'..."

# Ensure sudoers file is updated to allow passwordless sudo for specific Docker commands
echo "$LOCAL_USER ALL=(ALL) NOPASSWD: \
    /usr/bin/docker attach vmangos-mangos, \
    /usr/bin/docker ps, \
    /usr/bin/docker stats, \
    /usr/bin/docker compose *, \
    /usr/bin/docker exec vmangos-database /home/default/scripts/01-mangos-database-backup.sh, \
    /usr/bin/docker exec vmangos-database /home/default/scripts/01-population-balance-collect.sh, \
    /usr/bin/docker exec vmangos-database /home/default/scripts/02-characters-logs-realmd-databases-backup.sh, \
    /usr/bin/docker exec vmangos-database /home/default/scripts/03-binary-log-backup.sh" | tee /etc/sudoers.d/$LOCAL_USER-docker > /dev/null

# Verify if sudoers file was created
if [ -f /etc/sudoers.d/$LOCAL_USER-docker ]; then
    # Ensure the sudoers file has the correct permissions
    chmod 440 /etc/sudoers.d/$LOCAL_USER-docker
    echo "Passwordless sudo for Docker commands has been configured for user '$LOCAL_USER'."
else
    echo "Failed to configure passwordless sudo for Docker commands."
    exit 1
fi


# End of script


