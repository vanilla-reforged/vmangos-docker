#!/bin/bash

# ==============================
# Configurable Variables
# ==============================

# Percentage of total host memory to allocate (e.g., 75 for 75%)
MEMORY_USAGE_PERCENTAGE=75

# Fixed memory reservations (in gigabytes)
MEM_RESERVATION_DB=2  # Example: 2 GB
MEM_RESERVATION_MANGOS=2  # Example: 2 GB
MEM_RESERVATION_REALMD=0.5  # Example: 500 MB

# CPU share multipliers to ensure higher priority over default containers
# Set the base CPU shares (default is 1024)
BASE_CPU_SHARES=1024

# Multiplier to adjust CPU shares above the default
CPU_SHARE_MULTIPLIER_DB=10
CPU_SHARE_MULTIPLIER_MANGOS=10
CPU_SHARE_MULTIPLIER_REALMD=5

# Enable swap limit support (true/false)
ENABLE_SWAP_LIMIT_SUPPORT=true

# ==============================
# Script Logic (No Need to Modify Below)
# ==============================

# Stop all running containers
echo "Stopping all running Docker containers..."
sudo docker stop $(sudo docker ps -q)

# Initialize a flag to indicate whether a reboot is required
REBOOT_REQUIRED=false

# Function to check if swap limit support is enabled
is_swap_limit_enabled() {
  if grep -q "swapaccount=1" /proc/cmdline; then
    return 0  # Swap limit support is enabled
  else
    return 1  # Swap limit support is not enabled
  fi
}

# Check if swap limit support needs to be enabled
if [ "$ENABLE_SWAP_LIMIT_SUPPORT" = true ]; then
  if is_swap_limit_enabled; then
    echo "Swap limit support is already enabled."
  else
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
      echo "Error: Root privileges are required to enable swap limit support."
      echo "Please run this script as root or with sudo."
      exit 1
    fi

    echo "Enabling swap limit support..."

    # Backup the current grub file
    cp /etc/default/grub /etc/default/grub.backup.$(date +%F_%T)

    # Check if the grub parameter already exists
    if grep -q "swapaccount=1" /etc/default/grub; then
      echo "Swap limit support is already configured in /etc/default/grub."
    else
      # Update the GRUB_CMDLINE_LINUX parameter
      if grep -q '^GRUB_CMDLINE_LINUX="' /etc/default/grub; then
        # GRUB_CMDLINE_LINUX exists, append the parameter
        sed -i 's/^\(GRUB_CMDLINE_LINUX=".*\)"$/\1 cgroup_enable=memory swapaccount=1"/' /etc/default/grub
      else
        # GRUB_CMDLINE_LINUX does not exist, add it
        echo 'GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"' >> /etc/default/grub
      fi
      echo "Updated /etc/default/grub with swap limit support."
    fi

    echo "Running update-grub..."
    update-grub

    # Set the flag to indicate that a reboot is required
    REBOOT_REQUIRED=true
  fi
fi

# ==============================
# Configure Docker options
# ==============================
echo "Configuring Docker options..."
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Restart Docker to apply changes
sudo systemctl restart docker

# ==============================
# Update or add variables in the .env file
# ==============================

# Function to update or add a variable in the .env file
update_env_variable() {
  var_name=$1
  var_value=$2
  if [ -z "$var_value" ]; then
    echo "Warning: Skipping update of $var_name as value is empty."
    return
  fi

  if grep -q "^${var_name}=" .env; then
    # Variable exists, update it
    sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" .env
  else
    # Variable doesn't exist, append it
    # Ensure the .env file ends with a newline before appending
    if [ -s .env ] && [ -n "$(tail -c1 .env)" ]; then
      echo "" >> .env
    fi
    echo "${var_name}=${var_value}" >> .env
  fi
}

# Ensure the .env file exists
touch .env

# Update or add resource reservation, limit, and swap limit variables in gigabytes
mem_limit_db=$MEM_RESERVATION_DB
mem_limit_mangos=$MEM_RESERVATION_MANGOS
mem_limit_realmd=$MEM_RESERVATION_REALMD

# Calculate memswap limits (twice the mem limit)
memswap_limit_db=$(awk "BEGIN {print 2 * $mem_limit_db}")
memswap_limit_mangos=$(awk "BEGIN {print 2 * $mem_limit_mangos}")
memswap_limit_realmd=$(awk "BEGIN {print 2 * $mem_limit_realmd}")

# Calculate CPU shares for each container
cpu_shares_db=$(awk "BEGIN {printf \"%d\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_DB}")
cpu_shares_mangos=$(awk "BEGIN {printf \"%d\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_MANGOS}")
cpu_shares_realmd=$(awk "BEGIN {printf \"%d\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_REALMD}")

# Ensure CPU shares are integers and not empty
if ! [[ "$cpu_shares_db" =~ ^[0-9]+$ ]]; then
  cpu_shares_db=1024  # Default value
fi
if ! [[ "$cpu_shares_mangos" =~ ^[0-9]+$ ]]; then
  cpu_shares_mangos=1024  # Default value
fi
if ! [[ "$cpu_shares_realmd" =~ ^[0-9]+$ ]]; then
  cpu_shares_realmd=1024  # Default value
fi

# Update or add variables to the .env file
update_env_variable "MEM_RESERVATION_DB" "${MEM_RESERVATION_DB}g"
update_env_variable "MEM_RESERVATION_MANGOS" "${MEM_RESERVATION_MANGOS}g"
update_env_variable "MEM_RESERVATION_REALMD" "${MEM_RESERVATION_REALMD}g"

update_env_variable "MEM_LIMIT_DB" "${mem_limit_db}g"
update_env_variable "MEM_LIMIT_MANGOS" "${mem_limit_mangos}g"
update_env_variable "MEM_LIMIT_REALMD" "${mem_limit_realmd}g"

update_env_variable "MEMSWAP_LIMIT_DB" "${memswap_limit_db}g"
update_env_variable "MEMSWAP_LIMIT_MANGOS" "${memswap_limit_mangos}g"
update_env_variable "MEMSWAP_LIMIT_REALMD" "${memswap_limit_realmd}g"

update_env_variable "CPU_SHARES_DB" "$cpu_shares_db"
update_env_variable "CPU_SHARES_MANGOS" "$cpu_shares_mangos"
update_env_variable "CPU_SHARES_REALMD" "$cpu_shares_realmd"

echo "Resource limits have been updated in the .env file:"
grep -E "MEM_RESERVATION_DB|MEM_RESERVATION_MANGOS|MEM_RESERVATION_REALMD|MEM_LIMIT_DB|MEM_LIMIT_MANGOS|MEM_LIMIT_REALMD|MEMSWAP_LIMIT_DB|MEMSWAP_LIMIT_MANGOS|MEMSWAP_LIMIT_REALMD|CPU_SHARES_DB|CPU_SHARES_MANGOS|CPU_SHARES_REALMD" .env

# ==============================
# Start Docker Compose services
# ==============================
echo "Starting Docker Compose services..."
sudo docker compose up -d

# ==============================
# Reboot if Required
# ==============================

if [ "$REBOOT_REQUIRED" = true ]; then
  echo "Swap limit support has been enabled. The system will reboot in 10 seconds..."
  sleep 10
  reboot
fi
