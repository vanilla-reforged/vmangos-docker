#!/bin/bash

# Store original directory
ORIG_DIR=$(pwd)

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Load environment variables
source ./../../.env-script

# Change back to original directory before proceeding
cd "$ORIG_DIR"

# ==============================
# Configurable Variables
# ==============================

# Percentage of total host memory to allocate (e.g., 75 for 75%)
MEMORY_USAGE_PERCENTAGE=75

# Define minimum reservations in gigabytes
MEM_RESERVATION_DB=1  # Example: 1 GB
MEM_RESERVATION_MANGOS=1.5  # Example: 1.5 GB
MEM_RESERVATION_REALMD=0.1  # Example: 100 MB

# CPU share multipliers, initialize with default values (same priority as other containers)
BASE_CPU_SHARES=1024
CPU_SHARE_MULTIPLIER_DB=1
CPU_SHARE_MULTIPLIER_MANGOS=1
CPU_SHARE_MULTIPLIER_REALMD=1

# Enable swap limit support (true/false)
ENABLE_SWAP_LIMIT_SUPPORT=true

# ==============================
# Script Logic (No Need to Modify Below)
# ==============================

# Stop all running containers
echo "Stopping all running Docker containers..."
docker stop $(docker ps -q)

REBOOT_REQUIRED=false

# Function to check if swap limit support is enabled
is_swap_limit_enabled() {
  if grep -q "swapaccount=1" /proc/cmdline; then
    return 0
  else
    return 1
  fi
}

# Check if swap limit support needs to be enabled
if [ "$ENABLE_SWAP_LIMIT_SUPPORT" = true ]; then
  if is_swap_limit_enabled; then
    echo "Swap limit support is already enabled."
  else
    if [ "$EUID" -ne 0 ]; then
      echo "Error: Root privileges are required to enable swap limit support."
      exit 1
    fi

    echo "Enabling swap limit support..."
    cp /etc/default/grub /etc/default/grub.backup.$(date +%F_%T)
    
    if grep -q "swapaccount=1" /etc/default/grub; then
      echo "Swap limit support is already configured in /etc/default/grub."
    else
      if grep -q '^GRUB_CMDLINE_LINUX="' /etc/default/grub; then
        sed -i 's/^\(GRUB_CMDLINE_LINUX=".*\)"$/\1 cgroup_enable=memory swapaccount=1"/' /etc/default/grub
      else
        echo 'GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"' >> /etc/default/grub
      fi
      echo "Updated /etc/default/grub with swap limit support."
    fi

    update-grub
    REBOOT_REQUIRED=true
  fi
fi

# ==============================
# Configure Docker options
# ==============================
echo "Configuring Docker options..."
tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl restart docker

# ==============================
# Update or add variables in the .env file
# ==============================

# Function to update or add a variable in the .env file
update_env_variable() {
  var_name=$1
  var_value=$2
  env_file="$DOCKER_DIRECTORY/.env"

  if [ -z "$var_value" ]; then
    echo "Warning: Skipping update of $var_name as value is empty."
    return
  fi

  if grep -q "^${var_name}=" "$env_file"; then
    sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" "$env_file"
  else
    if [ -s "$env_file" ] && [ -n "$(tail -c1 "$env_file")" ]; then
      echo "" >> "$env_file"
    fi
    echo "${var_name}=${var_value}" >> "$env_file"
  fi
}

# Ensure the .env file exists
touch "$DOCKER_DIRECTORY/.env"

# Update or add resource reservation, limit, and swap limit variables in gigabytes
mem_limit_db=$MEM_RESERVATION_DB
mem_limit_mangos=$MEM_RESERVATION_MANGOS
mem_limit_realmd=$MEM_RESERVATION_REALMD

memswap_limit_db=$(awk "BEGIN {print 2 * $mem_limit_db}")
memswap_limit_mangos=$(awk "BEGIN {print 2 * $mem_limit_mangos}")
memswap_limit_realmd=$(awk "BEGIN {print 2 * $mem_limit_realmd}")

cpu_shares_db=$(awk "BEGIN {printf \"%d\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_DB}")
cpu_shares_mangos=$(awk "BEGIN {printf \"%d\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_MANGOS}")
cpu_shares_realmd=$(awk "BEGIN {printf \"%d\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_REALMD}")

if ! [[ "$cpu_shares_db" =~ ^[0-9]+$ ]]; then
  cpu_shares_db=1024
fi
if ! [[ "$cpu_shares_mangos" =~ ^[0-9]+$ ]]; then
  cpu_shares_mangos=1024
fi
if ! [[ "$cpu_shares_realmd" =~ ^[0-9]+$ ]]; then
  cpu_shares_realmd=1024
fi

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
grep -E "MEM_RESERVATION_DB|MEM_RESERVATION_MANGOS|MEM_RESERVATION_REALMD|MEM_LIMIT_DB|MEM_LIMIT_MANGOS|MEM_LIMIT_REALMD|MEMSWAP_LIMIT_DB|MEMSWAP_LIMIT_MANGOS|MEMSWAP_LIMIT_REALMD|CPU_SHARES_DB|CPU_SHARES_MANGOS|CPU_SHARES_REALMD" "$DOCKER_DIRECTORY/.env"

# ==============================
# Create vmangos-network
# ==============================

echo "Creating vmangos-network..."
docker network create vmangos-network

# ==============================
# Start Docker Compose services
# ==============================
echo "Starting Docker Compose services..."
docker compose -f "$DOCKER_DIRECTORY/docker-compose.yml" up -d

# ==============================
# Reboot if Required
# ==============================

if [ "$REBOOT_REQUIRED" = true ]; then
  echo "Swap limit support has been enabled. The system will reboot in 10 seconds..."
  sleep 10
  reboot
fi
