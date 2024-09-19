# ==============================
# Resource Limit Calculations
# ==============================

total_mem_gb=$(awk "BEGIN {printf \"%.2f\", $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1048576}")
mem_limit_gb=$(awk "BEGIN {printf \"%.2f\", $total_mem_gb * $MEMORY_USAGE_PERCENTAGE / 100}")

# Calculate memory reservations based on the ratio
total_parts=$(awk "BEGIN {print $RATIO_DB + $RATIO_MANGOS + $RATIO_REALMD}")

# Ensure total_parts is not zero to prevent division errors
if [[ $(echo "$total_parts == 0" | bc -l) -eq 1 ]]; then
  total_parts=1
fi

mem_db_gb=$(awk "BEGIN {printf \"%.2f\", $mem_limit_gb * $RATIO_DB / $total_parts}")
mem_mangos_gb=$(awk "BEGIN {printf \"%.2f\", $mem_limit_gb * $RATIO_MANGOS / $total_parts}")
mem_realmd_gb=$(awk "BEGIN {printf \"%.2f\", $mem_limit_gb * $RATIO_REALMD / $total_parts}")

# Debugging: Print calculated values
echo "Calculated memory values:"
echo "  mem_db_gb: $mem_db_gb"
echo "  mem_mangos_gb: $mem_mangos_gb"
echo "  mem_realmd_gb: $mem_realmd_gb"

# Ensure memory reservations are not lower than the minimum values
mem_reservation_db=$(awk "BEGIN {print ($mem_db_gb < $MIN_MEM_DB) ? $MIN_MEM_DB : $mem_db_gb}")
mem_reservation_mangos=$(awk "BEGIN {print ($mem_mangos_gb < $MIN_MEM_MANGOS) ? $MIN_MEM_MANGOS : $mem_mangos_gb}")
mem_reservation_realmd=$(awk "BEGIN {print ($mem_realmd_gb < $MIN_MEM_REALMD) ? $MIN_MEM_REALMD : $mem_realmd_gb}")

# Debugging: Print reservations
echo "Calculated memory reservations:"
echo "  mem_reservation_db: $mem_reservation_db"
echo "  mem_reservation_mangos: $mem_reservation_mangos"
echo "  mem_reservation_realmd: $mem_reservation_realmd"

# Set mem limits to match reservations
mem_limit_db=$mem_reservation_db
mem_limit_mangos=$mem_reservation_mangos
mem_limit_realmd=$mem_reservation_realmd

# Debugging: Print limits
echo "Final memory limits:"
echo "  mem_limit_db: $mem_limit_db"
echo "  mem_limit_mangos: $mem_limit_mangos"
echo "  mem_limit_realmd: $mem_limit_realmd"

# Calculate memswap limits (twice the mem limit)
memswap_limit_db=$(awk "BEGIN {print 2 * $mem_limit_db}")
memswap_limit_mangos=$(awk "BEGIN {print 2 * $mem_limit_mangos}")
memswap_limit_realmd=$(awk "BEGIN {print 2 * $mem_limit_realmd}")

# Debugging: Print swap limits
echo "Calculated memswap limits:"
echo "  memswap_limit_db: $memswap_limit_db"
echo "  memswap_limit_mangos: $memswap_limit_mangos"
echo "  memswap_limit_realmd: $memswap_limit_realmd"

# ==============================
# Update or add variables in the .env file
# ==============================

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
