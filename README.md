# VMaNGOS Docker

A Docker setup for VMaNGOS.

## Dependencies

* Docker
* Docker Compose 2

## Security

### Docker and UFW

Docker-published ports can bypass normal UFW rules.

This project uses [Chaifeng's ufw-docker solution](https://github.com/chaifeng/ufw-docker) to allow UFW to control access to Docker-published ports without disabling Docker's iptables support.

The setup script configures Docker and the required UFW/Docker forwarding rules:

* **`./script/setup-01-docker-dependencies-install.sh`**

Only publish ports that must be publicly accessible.

### Tailscale

Use [Tailscale](https://tailscale.com/) for private database access:

```sh
sudo tailscale serve --tcp 3306 tcp://127.0.0.1:3306
```

### UFW Rules

Allow access from one IP:

```sh
sudo ufw allow from [your-client-ip]
sudo ufw route allow proto tcp from [your-client-ip] to any
```

Allow public access to ports `3724` and `8085`:

```sh
sudo ufw route allow proto tcp from any to any port 3724
sudo ufw route allow proto tcp from any to any port 8085
```

## Docker Setup

The default client version is `5875` (patch `1.12.1`).

The persistent VMaNGOS containers (`vmangos-database`, `vmangos-realmd`, and `vmangos-mangos`) run with UID `1000` and GID `1000` by default.

You can adjust these values in `.env`:

* `VMANGOS_USER_ID`
* `VMANGOS_GROUP_ID`

Using the same UID/GID on the host helps avoid permission issues with bind-mounted files.

Persistent runtime data is stored under:

```text
./vol/
```

Backups are stored separately under:

```text
./backup/
```

Operational scripts are stored under:

```text
./script/
```

### Clone the Repository

Using a host user with UID/GID `1000:1000`, such as the default Ubuntu user, is recommended.

```sh
git clone --recurse-submodules https://github.com/vanilla-reforged/vmangos-docker
cd vmangos-docker
```

### Adjust Environment Files

Configure the environment files for your installation:

* `.env` — Docker Compose configuration.
* `.env-script` — Host script configuration.
* `.env-vmangos-build` — Compiler and CMake build configuration.

The scripts determine the repository directory automatically from their own location. `DOCKER_DIRECTORY` is no longer required.

To make the server publicly accessible, configure `VMANGOS_REALM_IP` in `.env-script`.

### Generate or Extract Client Data

Copy the contents of your World of Warcraft client directory into:

```text
./vol/client-data/
```

Generating DBC, maps, vmaps, and mmaps can take several hours.

If you already have extracted client data, place it under:

```text
./vol/client-data-extracted/
```

and skip:

* **`./script/setup-04-client-data-extract.sh`**

Pre-extracted client data may also be available here:

https://www.ownedcore.com/forums/world-of-warcraft/world-of-warcraft-emulator-servers/wow-emu-general-releases/613280-elysium-core-1-12-repack-including-mmaps-optional-vendors.html

## Setup Scripts

Run the setup scripts in order.

* **`./script/setup-01-docker-dependencies-install.sh`**

  * Installs and configures Docker, Docker Compose, 7zip, UFW, jq, bc, expect, and the required passwordless Docker sudo commands.

* **`./script/setup-02-github-core-database-update.sh`**

  * Clones the VMaNGOS core and database repositories, extracts the world database, and merges core migrations.

* **`./script/setup-03-core-compile.sh`**

  * Builds the compiler image and compiles the VMaNGOS core.

* **`./script/setup-04-client-data-extract.sh`**

  * Extracts DBC, maps, vmaps, and mmaps from the client data.

* **`./script/setup-05-docker-resources-initialize.sh`**

  * Initializes Docker resource limits, configures Docker logging, creates the VMaNGOS Docker network if required, and starts the containers.

* **`./script/setup-06-vmangos-database-create.sh`**

  * Creates and imports the VMaNGOS databases, configures the database user and realm, enables binary logging, and restarts the database service.

## MySQL Configuration

Keep the MySQL root password consistent between the relevant environment files.

If you change the database password, also update the database connection settings in:

```text
./vol/configuration/mangosd.conf
./vol/configuration/realmd.conf
```

## Create an Account

Attach to the mangos container:

```sh
sudo docker attach vmangos-mangos
```

Create an account:

```text
account create <account name> <account password>
account set gmlevel <account name> <account level>
```

Detach without stopping the container by pressing:

<kbd>Ctrl</kbd>+<kbd>P</kbd>, then <kbd>Ctrl</kbd>+<kbd>Q</kbd>.

## Starting and Stopping VMaNGOS

Stop the environment:

```sh
sudo docker compose down
```

Start the environment:

```sh
sudo docker compose up -d
```

## Operational Scripts

All operational scripts are stored directly under:

```text
./script/
```

Cron output logs are written beside their corresponding scripts.

Add the following to `.gitignore`:

```gitignore
script/*.log
```

### Backup

* **`./script/backup-01-mangos-database.sh`**

  * Creates an SQL dump of the `mangos` database.

* **`./script/backup-02-characters-logs-realmd-databases.sh`**

  * Creates and compresses an SQL dump of the `characters`, `logs`, and `realmd` databases.

* **`./script/backup-03-binary-log.sh`**

  * Copies and compresses MariaDB binary logs.

* **`./script/backup-04-s3-upload.sh`**

  * Uploads `.7z` backup files to S3.

* **`./script/backup-05-retention-cleanup.sh`**

  * Deletes old `.7z` backup files according to the configured retention period.

### Docker Resources

* **`./script/docker-resources-01-collect.sh`**

  * Collects memory usage data for the database, mangos, and realmd containers.

* **`./script/docker-resources-02-adjust.sh`**

  * Adjusts Docker resource allocations based on seven-day average memory usage and restarts the Docker Compose environment.

### Faction Balancer

* **`./script/faction-balancer-01-population-collect.sh`**

  * Collects Alliance and Horde population data.

* **`./script/faction-balancer-02-xp-rates-update.sh`**

  * Calculates faction balance from the previous seven days, updates faction-specific XP rates, removes old population data, and schedules a mangos server restart.
  * Requires [Vanilla Reforged - Faction specific XP rates](https://github.com/vmangos/core/commit/6a91ac278954431f615583ddf98137efede74232).

### Logs

* **`./script/logs-01-vmangos-cleanup.sh`**

  * Removes entries older than 21 days from mangos, honor, and realmd logs.
  * Preserves the existing log files, ownership, permissions, and file inodes.

### Management

* **`./script/management-01-vmangos-database-migrations-import.sh`**

  * Imports current database migrations and restarts the Docker Compose environment.

* **`./script/management-02-vmangos-database-world-recreate.sh`**

  * Recreates and imports the VMaNGOS world database and world migrations.

* **`./script/management-03-core-recompile.sh`**

  * Stops the environment, rebuilds and recompiles the VMaNGOS core, and starts the environment again.

* **`./script/management-04-vmangos-shutdown.sh`**

  * Disables automatic restart for `vmangos-mangos` and schedules a graceful shutdown after 15 minutes.

* **`./script/management-05-vmangos-startup.sh`**

  * Enables the automatic restart policy for `vmangos-mangos` and starts the container if it is stopped.

### Monitoring

* **`./script/monitoring-01-mangos-uptime.sh`**

  * Reads the current VMaNGOS uptime and sends the uptime, calculated last restart time, and current server time to Discord.

* **`./script/monitoring-02-docker-host-free-space.sh`**

  * Sends Docker host disk-space usage to Discord.

## Cron Jobs

Edit users's crontab:

```sh
crontab -e
```

Change `/home/user/vmangos-docker` to match your installation path.

```cron
##########
# Backup #
##########

# Weekly mangos database backup - Sunday at 01:40 AM
# 40 1 * * 0 /home/user/vmangos-docker/script/backup-01-mangos-database.sh >> /home/user/vmangos-docker/script/backup-01-mangos-database.log 2>&1

# Daily character/logs/realmd databases backup - 02:50 AM
50 2 * * * /home/user/vmangos-docker/script/backup-02-characters-logs-realmd-databases.sh >> /home/user/vmangos-docker/script/backup-02-characters-logs-realmd-databases.log 2>&1

# Tri-hourly binary log backup - 15 minutes past every third hour
15 */3 * * * /home/user/vmangos-docker/script/backup-03-binary-log.sh >> /home/user/vmangos-docker/script/backup-03-binary-log.log 2>&1

# Daily S3 upload backup - 12:10 PM
# 10 12 * * * /home/user/vmangos-docker/script/backup-04-s3-upload.sh >> /home/user/vmangos-docker/script/backup-04-s3-upload.log 2>&1

# Daily backup retention cleanup - 03:25 AM
25 3 * * * /home/user/vmangos-docker/script/backup-05-retention-cleanup.sh >> /home/user/vmangos-docker/script/backup-05-retention-cleanup.log 2>&1


####################
# Docker Resources #
####################

# Hourly resource collection - 30 minutes past each hour
30 * * * * /home/user/vmangos-docker/script/docker-resources-01-collect.sh >> /home/user/vmangos-docker/script/docker-resources-01-collect.log 2>&1

# Weekly resource adjustment - Sunday at 05:00 AM
0 5 * * 0 /home/user/vmangos-docker/script/docker-resources-02-adjust.sh >> /home/user/vmangos-docker/script/docker-resources-02-adjust.log 2>&1


####################
# Faction Balancer #
####################

# Hourly population data collection - 40 minutes past each hour
40 * * * * /home/user/vmangos-docker/script/faction-balancer-01-population-collect.sh >> /home/user/vmangos-docker/script/faction-balancer-01-population-collect.log 2>&1

# Daily faction XP rates update - 04:00 AM
0 4 * * * /home/user/vmangos-docker/script/faction-balancer-02-xp-rates-update.sh >> /home/user/vmangos-docker/script/faction-balancer-02-xp-rates-update.log 2>&1


########
# Logs #
########

# Weekly logs cleanup - Sunday at 12:00 PM
0 12 * * 0 /home/user/vmangos-docker/script/logs-01-vmangos-cleanup.sh >> /home/user/vmangos-docker/script/logs-01-vmangos-cleanup.log 2>&1


##############
# Monitoring #
##############

# Daily mangos uptime to Discord - 03:50 AM
50 3 * * * /home/user/vmangos-docker/script/monitoring-01-mangos-uptime.sh >> /home/user/vmangos-docker/script/monitoring-01-mangos-uptime.log 2>&1

# Daily Docker host free space to Discord - 03:55 AM
55 3 * * * /home/user/vmangos-docker/script/monitoring-02-docker-host-free-space.sh >> /home/user/vmangos-docker/script/monitoring-02-docker-host-free-space.log 2>&1
```

## Vanilla Reforged

* [Vanilla Reforged Website](https://vanillareforged.org/)
* [Vanilla Reforged Discord](https://discord.gg/KkkDV5zmPb)

## Support

* [Patreon](https://www.patreon.com/flyingfrog23)
* [Buy Me a Coffee](https://buymeacoffee.com/flyingfrog23)

## Based Upon

* [tonymmm1 vmangos-docker](https://github.com/tonymmm1/vmangos-docker)
* [mserajnik vmangos-docker](https://github.com/mserajnik/vmangos-deploy)
