#!/bin/bash

# ==============================
# Configurable Variables
# ==============================

# Percentage of total host memory to allocate (e.g., 75 for 75%)
MEMORY_USAGE_PERCENTAGE=75

# Base CPU shares (default is 1024)
BASE_CPU_SHARES=1024

# Multiplier to adjust CPU shares for each container
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

# Stop all running Docker containers using docker compose
echo "Stopping all running Docker containers..."
if ! sudo docker compose down; then
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

    sed -i 's/^\(GRUB_CMDLINE_LINUX=".*\)"$/\1 cgroup_enable=memory swapaccount=1"/' /etc/default/grub
    echo "Updated /etc/default/grub with swap limit support."
    
    echo "Running update-grub..."
    update-grub || { echo "Error: Failed to run update-grub."; exit 1; }
    REBOOT_REQUIRED=true
  fi
fi

# ==============================
# Resource Limit Calculations
# ==============================

# Get total memory in GB
total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_mem_gb=$(echo "scale=2; $total_mem_kb / 1024 / 1024" | bc)
mem_limit_gb=$(echo "scale=2; $total_mem_gb * $MEMORY_USAGE_PERCENTAGE / 100" | bc)

# Calculate memory reservations
mem_reservation_db=$(echo "scale=2; if ($mem_limit_gb / 3 < $MIN_MEM_DB) $MIN_MEM_DB else $mem_limit_gb / 3" | bc)
mem_reservation_mangos=$(echo "scale=2; if ($mem_limit_gb / 3 < $MIN_MEM_MANGOS) $MIN_MEM_MANGOS else $mem_limit_gb / 3" | bc)
mem_reservation_realmd=$(echo "scale=2; if ($mem_limit_gb / 3 < $MIN_MEM_REALMD) $MIN_MEM_REALMD else $mem_limit_gb / 3" | bc)

# Set limits to match reservations
mem_limit_db=$mem_reservation_db
mem_limit_mangos=$mem_reservation_mangos
mem_limit_realmd=$mem_reservation_realmd

# Calculate memswap limits (twice the mem limit)
memswap_limit_db=$(echo "scale=2; 2 * $mem_limit_db" | bc)
memswap_limit_mangos=$(echo "scale=2; 2 * $mem_limit_mangos" | bc)
memswap_limit_realmd=$(echo "scale=2; 2 * $mem_limit_realmd" | bc)

# ==============================
# CPU Shares Calculation
# ==============================
cpu_shares_db=$(echo "scale=0; $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_DB / 1" | bc)
cpu_shares_mangos=$(echo "scale=0; $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_MANGOS / 1" | bc)
cpu_shares_realmd=$(echo "scale=0; $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_REALMD / 1" | bc)

# Ensure CPU shares are integers and not empty
cpu_shares_db=${cpu_shares_db:-1024}
cpu_shares_mangos=${cpu_shares_mangos:-1024}
cpu_shares_realmd=${cpu_shares_realmd:-1024}

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
