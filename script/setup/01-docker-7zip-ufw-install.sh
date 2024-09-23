#!/bin/bash

# This script installs Docker, Docker Compose, 7zip, and sets up ufw-docker on an Ubuntu system

# Step 1: Update the package index
echo "Updating package index..."
sudo apt-get update -y

# Step 2: Install required packages for Docker installation
echo "Installing required packages..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Step 3: Add Docker’s official GPG key
echo "Adding Docker's official GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Step 4: Set up the Docker repository
echo "Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Step 5: Update the package index again
echo "Updating package index again..."
sudo apt-get update -y

# Step 6: Install Docker Engine, CLI, Containerd, and Docker Compose
echo "Installing Docker Engine and Docker Compose..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Step 7: Verify Docker installation
echo "Verifying Docker installation..."
sudo docker --version

# Step 8: Verify Docker Compose installation
echo "Verifying Docker Compose installation..."
sudo docker compose version

# Step 9: Install 7zip
echo "Installing 7zip..."
sudo apt-get install -y p7zip-full

# Step 10: Revoke the original modification and apply new UFW configuration

echo "Reverting any previous modifications and applying UFW configuration..."

# Revert changes to Docker and UFW configurations
sudo sed -i '/--iptables=false/d' /etc/docker/daemon.json
sudo sed -i '/FORWARD/d' /etc/ufw/after.rules
sudo systemctl restart docker

# Modify the UFW configuration file to add Docker rules
sudo tee -a /etc/ufw/after.rules > /dev/null <<EOF

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
sudo systemctl restart ufw
sudo ufw enable

# Clean up temporary files
sudo rm -rf ./ufw-docker

# Step 11: Notify the user about Docker usage
echo "Installation complete! Note: Since you are not added to the Docker group, you will need to use 'sudo' when running Docker commands."

# Step 12: Check if jq is installed; if not, attempt to install it
install_jq() {
  if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Attempting to install jq..."
    if [ -x "$(command -v apt-get)" ]; then
      sudo apt-get update && sudo apt-get install -y jq
    elif [ -x "$(command -v yum)" ]; then
      sudo yum install -y jq
    elif [ -x "$(command -v dnf)" ]; then
      sudo dnf install -y jq
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

# End of script
