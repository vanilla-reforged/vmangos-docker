#!/bin/bash

# ==============================
# Configurable Variables
# ==============================

# Percentage of total host memory to allocate (e.g., 75 for 75%)
MEMORY_USAGE_PERCENTAGE=75

# Resource ratio for the containers (can be decimal numbers)
RATIO_DB=3.0
RATIO_MANGOS=1.0
RATIO_REALMD=1.0

# CPU share multipliers to ensure higher priority over default containers
# Set the base CPU shares (default is 1024)
BASE_CPU_SHARES=1024

# Multiplier to adjust CPU shares above the default (e.g., 1.5 for 150%)
CPU_SHARE_MULTIPLIER_MANGOS=1.5
CPU_SHARE_MULTIPLIER_REALMD=1.5
CPU_SHARE_MULTIPLIER_DB=4.5  # To maintain the ratio

# Enable swap limit support (true/false)
ENABLE_SWAP_LIMIT_SUPPORT=true

# ==============================
# Script Logic (No Need to Modify Below)
# ==============================

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
# Resource Limit Calculations
# ==============================

# 1. Get total system memory in bytes
total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_mem_bytes=$(($total_mem_kb * 1024))

# 2. Calculate specified percentage of total memory
mem_limit=$(awk "BEGIN {printf \"%.0f\", $total_mem_bytes * $MEMORY_USAGE_PERCENTAGE / 100}")

# 3. Total ratio parts
total_parts=$(awk "BEGIN {print $RATIO_DB + $RATIO_MANGOS + $RATIO_REALMD}")

# 4. Calculate memory limits for each container based on the ratio
mem_db=$(awk "BEGIN {printf \"%.0f\", $mem_limit * $RATIO_DB / $total_parts}")
mem_mangos=$(awk "BEGIN {printf \"%.0f\", $mem_limit * $RATIO_MANGOS / $total_parts}")
mem_realmd=$(awk "BEGIN {printf \"%.0f\", $mem_limit * $RATIO_REALMD / $total_parts}")

# 5. Convert memory limits to bytes with 'b' suffix
mem_db_limit="${mem_db}b"
mem_mangos_limit="${mem_mangos}b"
mem_realmd_limit="${mem_realmd}b"

# 6. Calculate CPU shares for each container
cpu_shares_db=$(awk "BEGIN {printf \"%.0f\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_DB}")
cpu_shares_mangos=$(awk "BEGIN {printf \"%.0f\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_MANGOS}")
cpu_shares_realmd=$(awk "BEGIN {printf \"%.0f\", $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_REALMD}")

# 7. Update or add variables in the .env file

# Function to update or add a variable in the .env file
update_env_variable() {
  var_name=$1
  var_value=$2
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

# Update or add resource limit variables
update_env_variable "MEM_LIMIT_DB" "${mem_db_limit}"
update_env_variable "MEM_LIMIT_MANGOS" "${mem_mangos_limit}"
update_env_variable "MEM_LIMIT_REALMD" "${mem_realmd_limit}"

update_env_variable "CPU_SHARES_DB" "${cpu_shares_db}"
update_env_variable "CPU_SHARES_MANGOS" "${cpu_shares_mangos}"
update_env_variable "CPU_SHARES_REALMD" "${cpu_shares_realmd}"

echo "Resource limits have been updated in the .env file:"
grep -E "MEM_LIMIT_DB|MEM_LIMIT_MANGOS|MEM_LIMIT_REALMD|CPU_SHARES_DB|CPU_SHARES_MANGOS|CPU_SHARES_REALMD" .env

# ==============================
# Reboot if Required
# ==============================

if [ "$REBOOT_REQUIRED" = true ]; then
  echo "Swap limit support has been enabled. The system will reboot in 10 seconds..."
  sleep 10
  reboot
fi
