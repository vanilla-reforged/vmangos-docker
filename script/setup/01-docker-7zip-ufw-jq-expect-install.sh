#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

readonly ENV_SCRIPT_FILE="$PROJECT_ROOT/.env-script"
readonly UFW_RULES_FILE="/etc/ufw/after.rules"
readonly UFW_DEFAULT_FILE="/etc/default/ufw"
readonly DOCKER_DAEMON_FILE="/etc/docker/daemon.json"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    printf '[%s] [%s] [%s] %s\n' "$timestamp" "$SCRIPT_NAME" "$level" "$message"
}

configure_docker_iptables() {
    local temp_file

    log_message "INFO" "Checking Docker iptables configuration"

    # Docker uses iptables by default. Chaifeng's ufw-docker solution
    # requires Docker's normal iptables handling to remain enabled.
    if ! sudo test -e "$DOCKER_DAEMON_FILE"; then
        log_message "INFO" \
            "Docker daemon configuration not present; using Docker defaults"
        return
    fi

    if ! sudo test -s "$DOCKER_DAEMON_FILE"; then
        log_message "INFO" \
            "Docker daemon configuration is empty; using Docker defaults"
        return
    fi

    if ! sudo jq empty "$DOCKER_DAEMON_FILE" > /dev/null 2>&1; then
        log_message "ERROR" \
            "Invalid JSON in $DOCKER_DAEMON_FILE"
        return 1
    fi

    if ! sudo jq -e 'has("iptables")' \
        "$DOCKER_DAEMON_FILE" > /dev/null; then

        log_message "INFO" \
            "Docker iptables configuration already uses the default"
        return
    fi

    log_message "INFO" \
        "Removing custom Docker iptables setting"

    temp_file=$(mktemp)

    if ! sudo jq 'del(.iptables)' \
        "$DOCKER_DAEMON_FILE" > "$temp_file"; then

        rm -f "$temp_file"

        log_message "ERROR" \
            "Failed to update Docker daemon configuration"
        return 1
    fi

    sudo install \
        -o root \
        -g root \
        -m 0644 \
        "$temp_file" \
        "$DOCKER_DAEMON_FILE"

    rm -f "$temp_file"

    log_message "INFO" \
        "Restarting Docker after daemon configuration change"

    sudo systemctl restart docker

    log_message "SUCCESS" \
        "Docker iptables configuration restored to default"
}

configure_ufw_docker() {
    local backup_file

    log_message "INFO" "Configuring UFW for Docker"

    if [ ! -f "$UFW_RULES_FILE" ]; then
        log_message "ERROR" \
            "UFW rules file not found: $UFW_RULES_FILE"
        return 1
    fi

    if [ ! -f "$UFW_DEFAULT_FILE" ]; then
        log_message "ERROR" \
            "UFW defaults file not found: $UFW_DEFAULT_FILE"
        return 1
    fi

    # Back up the current UFW rules before changing them
    backup_file="${UFW_RULES_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    log_message "INFO" \
        "Backing up UFW rules to $backup_file"

    sudo cp \
        "$UFW_RULES_FILE" \
        "$backup_file"

    # Chaifeng recommends restoring UFW's default FORWARD policy to DROP
    if grep -q '^DEFAULT_FORWARD_POLICY=' "$UFW_DEFAULT_FILE"; then
        sudo sed -i \
            's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="DROP"/' \
            "$UFW_DEFAULT_FILE"
    else
        printf '%s\n' \
            'DEFAULT_FORWARD_POLICY="DROP"' |
            sudo tee -a "$UFW_DEFAULT_FILE" > /dev/null
    fi

    log_message "INFO" \
        "UFW default forwarding policy set to DROP"

    # Remove an existing ufw-docker block so this script can be rerun safely
    sudo sed -i \
        '/^# BEGIN UFW AND DOCKER$/,/^# END UFW AND DOCKER$/d' \
        "$UFW_RULES_FILE"

    # Chaifeng ufw-docker conntrack rules
    sudo tee -a "$UFW_RULES_FILE" > /dev/null <<'EOF'

# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:ufw-docker-logging-deny - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw-user-forward

-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP
-A DOCKER-USER -i docker0 -o docker0 -j ACCEPT

-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

-A DOCKER-USER -j ufw-docker-logging-deny -m conntrack --ctstate NEW -d 10.0.0.0/8
-A DOCKER-USER -j ufw-docker-logging-deny -m conntrack --ctstate NEW -d 172.16.0.0/12
-A DOCKER-USER -j ufw-docker-logging-deny -m conntrack --ctstate NEW -d 192.168.0.0/16

-A DOCKER-USER -j RETURN

-A ufw-docker-logging-deny -m limit --limit 3/min --limit-burst 10 -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A ufw-docker-logging-deny -j DROP

COMMIT
# END UFW AND DOCKER
EOF

    if sudo ufw status | grep -q '^Status: active'; then
        log_message "INFO" "Reloading UFW"

        sudo ufw reload

        log_message "SUCCESS" \
            "UFW Docker configuration applied"
    else
        log_message "WARNING" \
            "UFW is disabled; Docker rules were installed but UFW was not enabled"

        log_message "WARNING" \
            "Configure SSH access before enabling UFW if this is a remote server"
    fi
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

    if ! sudo visudo -cf "$temp_file" > /dev/null; then
        rm -f "$temp_file"

        log_message "ERROR" \
            "Generated sudoers configuration is invalid"

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

    # Load script configuration
    if [ ! -f "$ENV_SCRIPT_FILE" ]; then
        log_message "ERROR" \
            "Environment file not found: $ENV_SCRIPT_FILE"
        return 1
    fi

    source "$ENV_SCRIPT_FILE"

    if [ -z "${LOCAL_USER:-}" ]; then
        log_message "ERROR" \
            "LOCAL_USER is not configured in $ENV_SCRIPT_FILE"
        return 1
    fi

    if ! id "$LOCAL_USER" > /dev/null 2>&1; then
        log_message "ERROR" \
            "Local user does not exist: $LOCAL_USER"
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
    log_message "INFO" \
        "Configuring Docker package repository"

    sudo install \
        -m 0755 \
        -d /etc/apt/keyrings

    sudo curl -fsSL \
        https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

    sudo chmod a+r \
        /etc/apt/keyrings/docker.asc

    # Remove repository files used by the old installation method
    sudo rm -f \
        /etc/apt/keyrings/docker.gpg \
        /etc/apt/sources.list.d/docker.list

    source /etc/os-release

    ubuntu_codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    architecture=$(dpkg --print-architecture)

    sudo tee \
        /etc/apt/sources.list.d/docker.sources \
        > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $ubuntu_codename
Components: stable
Architectures: $architecture
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    # Install Docker
    log_message "INFO" \
        "Updating package index with Docker repository"

    sudo apt-get update

    log_message "INFO" \
        "Installing Docker Engine and Docker Compose"

    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Verify installation
    log_message "INFO" \
        "Verifying Docker installation"

    docker --version
    docker compose version

    # Restore Docker's normal iptables behavior
    configure_docker_iptables

    # Configure UFW/Docker integration
    configure_ufw_docker

    # Configure passwordless Docker commands
    configure_sudoers

    log_message "SUCCESS" \
        "Script completed successfully"
}

main "$@"
