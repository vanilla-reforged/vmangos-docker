#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly ENV_SCRIPT_FILE="$PROJECT_ROOT/.env-script"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

configure_ufw_docker() {
    readonly UFW_RULES_FILE="/etc/ufw/after.rules"

    log_message "INFO" "Configuring UFW for Docker"

    # Remove an existing VMaNGOS Docker block to make this idempotent
    sudo sed -i \
        '/^# BEGIN UFW AND DOCKER$/,/^# END UFW AND DOCKER$/d' \
        "$UFW_RULES_FILE"

    sudo tee -a "$UFW_RULES_FILE" > /dev/null <<'EOF'

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

-A ufw-docker-logging-deny -m limit --limit 3/min --limit-burst 10 \
    -j LOG --log-prefix "[UFW DOCKER BLOCK] "

-A ufw-docker-logging-deny -j DROP

COMMIT
# END UFW AND DOCKER
EOF

    sudo ufw --force enable
    sudo systemctl restart ufw

    log_message "SUCCESS" "UFW Docker configuration applied"
}

configure_sudoers() {
    local sudoers_file="/etc/sudoers.d/${LOCAL_USER}-docker"
    local temp_file

    log_message "INFO" \
        "Configuring passwordless Docker commands for $LOCAL_USER"

    temp_file=$(mktemp)

    cat > "$temp_file" <<EOF
$LOCAL_USER ALL=(ALL) NOPASSWD: \
    /usr/bin/docker attach vmangos-mangos, \
    /usr/bin/docker ps *, \
    /usr/bin/docker stats *, \
    /usr/bin/docker container inspect *, \
    /usr/bin/docker inspect *, \
    /usr/bin/docker start vmangos-mangos, \
    /usr/bin/docker update --restart=no vmangos-mangos, \
    /usr/bin/docker update --restart=always vmangos-mangos, \
    /usr/bin/docker compose *, \
    /usr/bin/docker exec vmangos-database /home/default/scripts/01-mangos-database-backup.sh, \
    /usr/bin/docker exec vmangos-database /home/default/scripts/01-population-balance-collect.sh, \
    /usr/bin/docker exec vmangos-database /home/default/scripts/02-characters-logs-realmd-databases-backup.sh, \
    /usr/bin/docker exec vmangos-database /home/default/scripts/03-binary-log-backup.sh
EOF

    # Validate before installing the sudoers file
    if ! sudo visudo -cf "$temp_file" > /dev/null; then
        rm -f "$temp_file"

        log_message "ERROR" "Generated sudoers configuration is invalid"
        return 1
    fi

    sudo install \
        -o root \
        -g root \
        -m 0440 \
        "$temp_file" \
        "$sudoers_file"

    rm -f "$temp_file"

    log_message "SUCCESS" \
        "Passwordless Docker commands configured for $LOCAL_USER"
}

main() {
    local ubuntu_codename
    local architecture

    log_message "INFO" "Script started"

    # Load configuration
    if [ ! -f "$ENV_SCRIPT_FILE" ]; then
        log_message "ERROR" \
            "Environment file not found: $ENV_SCRIPT_FILE"
        return 1
    fi

    source "$ENV_SCRIPT_FILE"

    if [ -z "${LOCAL_USER:-}" ]; then
        log_message "ERROR" "LOCAL_USER is not configured"
        return 1
    fi

    if ! id "$LOCAL_USER" > /dev/null 2>&1; then
        log_message "ERROR" "Local user does not exist: $LOCAL_USER"
        return 1
    fi

    # Install base dependencies
    log_message "INFO" "Updating package index"
    sudo apt-get update

    log_message "INFO" "Installing base dependencies"

    sudo apt-get install -y \
        ca-certificates \
        curl \
        ufw \
        p7zip-full \
        jq \
        bc \
        expect

    # Configure Docker repository
    log_message "INFO" "Configuring Docker package repository"

    sudo install -m 0755 -d /etc/apt/keyrings

    sudo curl -fsSL \
        https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Remove files created by the previous repository configuration
    sudo rm -f \
        /etc/apt/keyrings/docker.gpg \
        /etc/apt/sources.list.d/docker.list

    source /etc/os-release

    ubuntu_codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    architecture=$(dpkg --print-architecture)

    sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $ubuntu_codename
Components: stable
Architectures: $architecture
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    # Install Docker
    log_message "INFO" "Updating package index with Docker repository"
    sudo apt-get update

    log_message "INFO" "Installing Docker Engine and Docker Compose"

    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Verify Docker
    log_message "INFO" "Verifying Docker installation"

    docker --version
    docker compose version

    # Configure firewall
    configure_ufw_docker

    # Configure passwordless Docker commands
    configure_sudoers

    log_message "SUCCESS" "Script completed successfully"
}

main "$@"
