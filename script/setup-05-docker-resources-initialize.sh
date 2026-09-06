#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly ENV_FILE="$PROJECT_ROOT/.env"
readonly COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
readonly DOCKER_NETWORK="vmangos-network"

readonly MEM_RESERVATION_DB=1
readonly MEM_RESERVATION_MANGOS=1.5
readonly MEM_RESERVATION_REALMD=0.1

readonly BASE_CPU_SHARES=1024
readonly CPU_SHARE_MULTIPLIER_DB=1
readonly CPU_SHARE_MULTIPLIER_MANGOS=1
readonly CPU_SHARE_MULTIPLIER_REALMD=1

readonly ENABLE_SWAP_LIMIT_SUPPORT=true

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

update_env_variable() {
    local variable_name="$1"
    local variable_value="$2"
    local temp_file

    temp_file=$(mktemp "${ENV_FILE}.tmp.XXXXXX")

    awk -v name="$variable_name" -v value="$variable_value" '
        $0 ~ "^" name "=" {
            print name "=" value
            updated = 1
            next
        }

        { print }

        END {
            if (!updated) {
                print name "=" value
            }
        }
    ' "$ENV_FILE" > "$temp_file"

    # Preserve ownership, permissions, and inode of .env
    cat "$temp_file" > "$ENV_FILE"
    rm -f "$temp_file"

    log_message "DEBUG" "Updated $variable_name=$variable_value"
}

configure_swap_limit_support() {
    local docker_info

    if [ "$ENABLE_SWAP_LIMIT_SUPPORT" != true ]; then
        return
    fi

    if ! docker_info=$(sudo docker info 2>&1); then
        log_message "ERROR" "Unable to check Docker swap limit support"
        return 1
    fi

    if ! grep -q "WARNING: No swap limit support" <<< "$docker_info"; then
        log_message "INFO" "Docker swap limit support is available"
        return
    fi

    log_message "WARNING" "Docker reports no swap limit support"

    if grep -q "swapaccount=1" /proc/cmdline; then
        log_message "WARNING" \
            "swapaccount=1 is active but Docker still reports no swap limit support"
        return
    fi

    log_message "INFO" "Enabling memory and swap accounting in GRUB"

    sudo cp \
        /etc/default/grub \
        "/etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)"

    if ! grep -q "swapaccount=1" /etc/default/grub; then
        if grep -q '^GRUB_CMDLINE_LINUX="' /etc/default/grub; then
            sudo sed -i \
                '/^GRUB_CMDLINE_LINUX=/ s/"$/ cgroup_enable=memory swapaccount=1"/' \
                /etc/default/grub
        else
            printf '%s\n' \
                'GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"' |
                sudo tee -a /etc/default/grub > /dev/null
        fi
    fi

    sudo update-grub

    REBOOT_REQUIRED=true

    log_message "WARNING" \
        "Swap limit support requires a reboot before the kernel change takes effect"
}

configure_docker_daemon() {
    local daemon_file="/etc/docker/daemon.json"
    local temp_file

    log_message "INFO" "Configuring Docker log rotation"

    sudo mkdir -p /etc/docker
    temp_file=$(mktemp)

    if sudo test -s "$daemon_file"; then
        if ! sudo jq \
            '. + {
                "log-driver": "json-file",
                "log-opts": ((.["log-opts"] // {}) + {
                    "max-size": "10m",
                    "max-file": "3"
                })
            }' \
            "$daemon_file" > "$temp_file"; then

            rm -f "$temp_file"

            log_message "ERROR" \
                "Failed to update Docker daemon configuration"
            return 1
        fi
    else
        jq -n '{
            "log-driver": "json-file",
            "log-opts": {
                "max-size": "10m",
                "max-file": "3"
            }
        }' > "$temp_file"
    fi

    sudo install \
        -o root \
        -g root \
        -m 0644 \
        "$temp_file" \
        "$daemon_file"

    rm -f "$temp_file"

    sudo systemctl restart docker

    log_message "SUCCESS" "Docker log rotation configured"
}

main() {
    local mem_limit_db
    local mem_limit_mangos
    local mem_limit_realmd

    local memswap_limit_db
    local memswap_limit_mangos
    local memswap_limit_realmd

    local cpu_shares_db
    local cpu_shares_mangos
    local cpu_shares_realmd

    REBOOT_REQUIRED=false

    log_message "INFO" "Script started"

    if [ ! -f "$COMPOSE_FILE" ]; then
        log_message "ERROR" \
            "Compose file not found: $COMPOSE_FILE"
        return 1
    fi

    # Ensure Compose environment file exists
    touch "$ENV_FILE"

    # Configure host
    configure_swap_limit_support
    configure_docker_daemon

    # Initial memory limits equal the configured reservations
    mem_limit_db="$MEM_RESERVATION_DB"
    mem_limit_mangos="$MEM_RESERVATION_MANGOS"
    mem_limit_realmd="$MEM_RESERVATION_REALMD"

    # Swap limits are twice the memory limits
    memswap_limit_db=$(
        awk "BEGIN { print 2 * $mem_limit_db }"
    )

    memswap_limit_mangos=$(
        awk "BEGIN { print 2 * $mem_limit_mangos }"
    )

    memswap_limit_realmd=$(
        awk "BEGIN { print 2 * $mem_limit_realmd }"
    )

    # Initial CPU shares
    cpu_shares_db=$(
        awk "BEGIN {
            printf \"%d\",
            $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_DB
        }"
    )

    cpu_shares_mangos=$(
        awk "BEGIN {
            printf \"%d\",
            $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_MANGOS
        }"
    )

    cpu_shares_realmd=$(
        awk "BEGIN {
            printf \"%d\",
            $BASE_CPU_SHARES * $CPU_SHARE_MULTIPLIER_REALMD
        }"
    )

    # Update Compose resource configuration
    log_message "INFO" \
        "Updating initial resource limits in $ENV_FILE"

    update_env_variable \
        "MEM_RESERVATION_DB" \
        "${MEM_RESERVATION_DB}g"

    update_env_variable \
        "MEM_RESERVATION_MANGOS" \
        "${MEM_RESERVATION_MANGOS}g"

    update_env_variable \
        "MEM_RESERVATION_REALMD" \
        "${MEM_RESERVATION_REALMD}g"

    update_env_variable \
        "MEM_LIMIT_DB" \
        "${mem_limit_db}g"

    update_env_variable \
        "MEM_LIMIT_MANGOS" \
        "${mem_limit_mangos}g"

    update_env_variable \
        "MEM_LIMIT_REALMD" \
        "${mem_limit_realmd}g"

    update_env_variable \
        "MEMSWAP_LIMIT_DB" \
        "${memswap_limit_db}g"

    update_env_variable \
        "MEMSWAP_LIMIT_MANGOS" \
        "${memswap_limit_mangos}g"

    update_env_variable \
        "MEMSWAP_LIMIT_REALMD" \
        "${memswap_limit_realmd}g"

    update_env_variable \
        "CPU_SHARES_DB" \
        "$cpu_shares_db"

    update_env_variable \
        "CPU_SHARES_MANGOS" \
        "$cpu_shares_mangos"

    update_env_variable \
        "CPU_SHARES_REALMD" \
        "$cpu_shares_realmd"

    log_message "SUCCESS" "Initial resource limits updated"

    grep -E \
        '^(MEM_RESERVATION|MEM_LIMIT|MEMSWAP_LIMIT|CPU_SHARES)_' \
        "$ENV_FILE"

    # Create network only when missing
    if sudo docker network inspect \
        "$DOCKER_NETWORK" > /dev/null 2>&1; then

        log_message "INFO" \
            "Docker network already exists: $DOCKER_NETWORK"
    else
        log_message "INFO" \
            "Creating Docker network: $DOCKER_NETWORK"

        sudo docker network create \
            "$DOCKER_NETWORK" > /dev/null

        log_message "SUCCESS" "Docker network created"
    fi

    # Start VMaNGOS environment
    log_message "INFO" "Starting Docker Compose environment"

    sudo docker compose \
        --project-directory "$PROJECT_ROOT" \
        --env-file "$ENV_FILE" \
        -f "$COMPOSE_FILE" \
        up -d

    log_message "SUCCESS" \
        "Docker Compose environment started"

    # Reboot only when swap accounting had to be enabled
    if [ "$REBOOT_REQUIRED" = true ]; then
        log_message "WARNING" \
            "System will reboot in 10 seconds to enable swap limit support"

        sleep 10
        sudo reboot
    fi

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
