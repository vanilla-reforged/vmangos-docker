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

# Step 9: Configure Docker log rotation
echo "Configuring Docker log rotation..."
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Step 10: Restart Docker to apply changes
echo "Restarting Docker..."
sudo systemctl restart docker

# Step 11: Install 7zip
echo "Installing 7zip..."
sudo apt-get install -y p7zip-full

# Step 13: Clone and run the ufw-docker script
echo "Setting up ufw-docker..."
git clone https://github.com/chaifeng/ufw-docker.git ./ufw-docker
sudo ./ufw-docker/ufw-docker

# Clean up temporary files
sudo rm -rf ./ufw-docker

# Step 14: Notify the user about Docker usage
echo "Installation complete! Note: Since you are not added to the Docker group, you will need to use 'sudo' when running Docker commands."

# End of script
