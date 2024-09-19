#!/bin/bash

# ==============================
# Configurable Variables
# ==============================

# Percentage of total host memory to allocate (e.g., 75 for 75%)
MEMORY_USAGE_PERCENTAGE=75

# CPU share multipliers to ensure higher priority over default containers
BASE_CPU_SHARES=1024

# Multiplier to adjust CPU shares above the default
CPU_SHARE_MULTIPLIER_DB=10
CPU_SHARE_MULTIPLIER_MANGOS=10
CPU_SHARE_MULTIPLIER_REALMD=5

# Enable swap limit support (true/false)
ENABLE_SWAP_LIMIT_SUPPORT=true

# Minimum memory reservations (in gigabytes)
MIN_MEM_DB=1
MIN_MEM_MANGOS=1
MIN_MEM_REALMD=0.1

# ==============================
# Script Logic
# ==============================

# Stop all running containers
echo "Stopping all running Docker containers..."
if ! sudo docker stop $(sudo docker ps -q); then
  echo "Error: Failed to stop Docker containers."
  exit 1
fi

# Initialize a flag to indicate whether a reboot is required
REBOOT_REQUIRED=false

# Function to check if swap limit support is enabled
is_swap_limit_enabled() {
  grep -q "swapaccount=1" /proc/cmdline
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
      echo "Swap limit support is already configured."
    else
      sed -i 's/^\(GRUB_CMDLINE_LINUX=".*\)"$/\1 cgroup_enable=memory swapaccount=1"/' /etc/default/grub || echo 'GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"' >> /etc/default/grub
      echo "Updated /etc/default/grub with swap limit support."
    fi

    echo "Running update-grub..."
    update-grub || { echo "Error: Failed to run update-grub."; exit 1; }
    REBOOT_REQUIRED=true
  fi
fi

# ==============================
# Resource Limit Calculations
# ==============================

total_mem_gb=$(awk "BEGIN {printf \"%.2f\", $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1048576}")
mem_limit_gb=$(awk "BEGIN {printf \"%.2f\", $total_mem_gb * $MEMORY_USAGE_PERCENTAGE / 100}")

# Calculate memory reservations based on the ratio
total_parts=$(awk "BEGIN {print $RATIO_DB + $RATIO_MANGOS + $RATIO_REALMD}")
mem_db_gb=$(awk "BEGIN {printf \"%.2f\", $mem_limit_gb * $RATIO_DB / $total_parts}")
mem_mangos_gb=$(awk "BEGIN {printf \"%.2f\", $mem_limit_gb * $RATIO_MANGOS / $total_parts}")
mem_realmd_gb=$(awk "BEGIN {printf \"%.2f\", $mem_limit_gb * $RATIO_REALMD / $total_parts}")

# Ensure memory reservations are not lower than the minimum values
mem_reservation_db=$(awk "BEGIN {print ($mem_db_gb < $MIN_MEM_DB) ? $MIN_MEM_DB : $mem_db_gb}")
mem_reservation_mangos=$(awk "BEGIN {print ($mem_mangos_gb < $MIN_MEM_MANGOS) ? $MIN_MEM_MANGOS : $mem_mangos_gb}")
mem_reservation_realmd=$(awk "BEGIN {print ($mem_realmd_gb < $MIN_MEM_REALMD) ? $MIN_MEM_REALMD : $mem_realmd_gb}")

# Set mem limits to match reservations
mem_limit_db=$mem_reservation_db
mem_limit_mangos=$mem_reservation_mangos
mem_limit_realmd=$mem_reservation_realmd

# Calculate memswap limits (twice the mem limit)
memswap_limit_db=$(awk "BEGIN {print 2 * $mem_limit_db}")
memswap_limit_mangos=$(awk "BEGIN {print 2 * $mem_limit_mangos}")
memswap_limit_realmd=$(awk "BEGIN {print 2 * $mem_limit_realmd}")

# Calculate CPU shares for each container
cpu_shares_db=$(awk "BEGIN {printf \"%d\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_DB}")
cpu_shares_mangos=$(awk "BEGIN {printf \"%d\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_MANGOS}")
cpu_shares_realmd=$(awk "BEGIN {printf \"%d\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_REALMD}")

# Ensure CPU shares are integers and not empty
cpu_shares_db=${cpu_shares_db:-1024}
cpu_shares_mangos=${cpu_shares_mangos:-1024}
cpu_shares_realmd=${cpu_shares_realmd:-1024}

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
if ! sudo systemctl restart docker; then
  echo "Error: Failed to restart Docker."
  exit 1
fi

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
    sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" .env
  else
    echo "${var_name}=${var_value}" >> .env
  fi
}

# Ensure the .env file exists
touch .env

# Update or add resource reservation, limit, and swap limit variables in gigabytes
update_env_variable "MEM_RESERVATION_DB" "${mem_reservation_db}g"
update_env_variable "MEM_RESERVATION_MANGOS" "${mem_reservation_mangos}g"
update_env_variable "MEM_RESERVATION_REALMD" "${mem_reservation_realmd}g"

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
if ! sudo docker compose up -d; then
  echo "Error: Failed to start Docker Compose services."
  exit 1
fi

# ==============================
# Reboot if Required
# ==============================

if [ "$REBOOT_REQUIRED" = true ]; then
  echo "Swap limit support has been enabled. The system will reboot in 10 seconds..."
  sleep 10
  reboot
fi
