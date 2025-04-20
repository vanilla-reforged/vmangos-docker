## A Docker setup for VMaNGOS.

## Todo

- Use docker swarm to leverage docker secrets.

## Dependencies

- Docker
- Docker compose 2
- A POSIX-compliant shell as well as various core utilities (such as `cp` and `rm`) if you intend to use the provided scripts to install, update, and manage VMaNGOS.

## Security

Secure your system by understanding the following information: [ufw-docker](https://github.com/chaifeng/ufw-docker).

The ufw commands you will need to secure your installation:

### Management:

```sh
ufw allow from [your client ip] to any
ufw route allow proto tcp from [your client ip] to any
```

### Public Access:

```sh
ufw route allow proto tcp from any to any port 3724
ufw route allow proto tcp from any to any port 8085
```

## Docker Setup

The assumed client version is `5875` (patch `1.12.1`); if you want to set up VMaNGOS to use a different version, modify the `VMANGOS_CLIENT` entry in the `.env` file accordingly.

The user that is used inside the persistent containers (VMANGOS_DATABASE, VMANGOS_REALMD, VMANGOS_MANGOS) has UID `1000` and GID `1000` by default. You can adjust this if needed; e.g., to match your host UID/GID. This requires editing the entries `VMANGOS_USER_ID` and `VMANGOS_GROUP_ID` in the `.env` file.

Also, please be aware that `./vol/client-data-extracted` gets mounted directly into the mangos server to provide dbc and map data.

### Clone the Repository

Important: Use a User with UID:GUID 1000:1000 for this step (default user on ubuntu), otherwise you will run in permission issues with the docker containers:

```sh
git clone --recurse-submodules https://github.com/vanilla-reforged/vmangos-docker
```

### Adjust .env Files

Adjust the .env files for your desired setup:

- `.env` For Docker Compose
- `.env-script` For Scripts
- `.env-vmangos-build` For compiler image build / to set the cmake options.

To use the scripts, change the `DOCKER_DIRECTORY` environment variable in the `.env-script` file to the absolute path to your vmangos-docker directory (f.e. `/home/user/vmangos-docker`). To make the server public, change the `VMANGOS_REALM_IP` environment variable in the `.env-script` file.

### Generate/Extract Client Data

Copy the contents of your World of Warcraft client directory into `./vol/client-data`. Generating the required data will take many hours. If you have already extracted the client data, place it in `./vol/client-data-extracted` and skip the `04-client-data-extract.sh` script. 

Note: Linux extractors for VMaNGOS currently have some issues, i suggest getting the required files from here: https://www.ownedcore.com/forums/world-of-warcraft/world-of-warcraft-emulator-servers/wow-emu-general-releases/613280-elysium-core-1-12-repack-including-mmaps-optional-vendors.html.

### Setup (/script/setup/)

- `sudo ./script/setup/01-docker-7zip-ufw-jq-expect-install.sh`
  - Install and modify Docker, 7zip, ufw, jq and expect.

- `sudo ./script/setup/02-github-core-database-update.sh`
  - Update the github directories in ./vol/.

- `sudo ./script/setup/03-core-compile.sh`
  - Compile the core.

- `sudo ./script/setup/04-client-data-extract.sh`
  - Extract the Client Data.

- `sudo ./script/setup/05-docker-resources-initialize.sh`
  - Initialize the ressource limits, based on the current hardware and start the containers.

- `sudo ./script/setup/06-vmangos-database-create.sh`
  - Create and modify the vmangos databases.

### Configure MySQL Password

Update `mangosd.conf` and `realmd.conf` with your MySQL root password if you changed it in `.env-script` .

### Create Account

Attach to the `vmangos_mangos` service:

```sh
sudo docker attach vmangos-mangos
```

Create the account:

```sh
account create <account name> <account password>
account set gmlevel <account name> <account level>
```

Detach from the Docker container:

Press <kbd>Ctrl</kbd>+<kbd>P</kbd> and <kbd>Ctrl</kbd>+<kbd>Q</kbd>.


## Stopping and Starting VMaNGOS

```sh
sudo docker compose down
sudo docker compose up -d
```

## Scripts

### Backup (/script/backup/)

- `./script/backup/01-mangos-database-backup.sh`
  - SQL Dump of Database mangos.

- `./script/backup/02-characters-logs-realmd-databases-backup.sh`
  - SQL Dump of Databases characters, logs, realmd.

- `./script/backup/03-binary-log-backup.sh`
  - Binary log backup.

- `./script/backup/04-s3-upload-backup.sh`
  - Upload backups to s3.

- `./script/backup/05-backup-retention-cleanup.sh`
  - Cleanup old Backups, retention is configurable in script.

### Docker-Resources (/script/docker-resources/)

- `./script/docker-resources/01-docker-resources-collect.sh`
  - Collect ressource usage for database, mangos and realmd containers.

- `./script/docker-resources/02-docker-resources-adjust.sh`
  - Adjusts ressource allocations in docker-compose.yml based on 7 day averages of the Data collected with `01-docker-resources-collect.sh` and restarts vmangos-mangos, vmangos-realmd and vmangos-database **through docker compose**.

### Faction Balancer (/script/faction-balancer/)

- `./script/faction-balancer/01-Population-Balance-Collect.sh`
  - Collect faction balance data.

- `./script/faction-balancer/02-Faction-Specific-XP-Rates-Update.sh`
  - Sets faction-specific XP rates and restarts vmangos-mangos **through the mangos console** to activate them. Requires core change [Vanilla Reforged - Faction specific XP rates](https://github.com/vmangos/core/commit/6a91ac278954431f615583ddf98137efede74232).

### Logs (/script/logs/)

- `./script/logs/01-vmangos-logs-cleanup.sh`
  - Cleanup mangos logs older than 3 days, honor logs older than 2 weeks, realmd logs older than 1 week. 

### Management (/script/management/)

- `sudo ./script/management/01-vmangos-database-migrations-import.sh`
  - Import new migrations.

- `sudo ./script/management/02-vmangos-database-world-recreate.sh`
  - Recreate the world database.

- `sudo ./script/management/03-core-recompile.sh`
  - Recompile the core.

- `sudo ./script/management/04-vmangos-shutdown.sh`
  - Shuts down the container vmangos-mangos after 15 minutes (with a player announcement) and configures it to **not** automatically restart.
 
- `sudo ./script/management/05-vmangos-startup.sh`
  - Starts the container vmangos-mangos and configures it to automatically restart.

#### Edit the crontab using the command below:

```sh
crontab -e
```

#### Add the following lines to the crontab file, change the paths to fit your installation:

```sh
##########
# Backup #
##########

# Weekly mangos database backup - Sunday at 01:40 AM
# 40 1 * * 0 /home/user/vmangos-docker/script/backup/01-mangos-database-backup.sh >> /home/user/vmangos-docker/script/crontab-logs/01-mangos-database-backup.log 2>&1

# Daily character/logs/realmd databases backup - 02:50 AM
50 2 * * * /home/user/vmangos-docker/script/backup/02-characters-logs-realmd-databases-backup.sh >> /home/user/vmangos-docker/script/crontab-logs/02-characters-logs-realmd-databases-backup.log 2>&1

# Hourly binary log backup - 15 minutes past each hour
15 * * * * /home/user/vmangos-docker/script/backup/03-binary-log-backup.sh >> /home/user/vmangos-docker/script/crontab-logs/03-binary-log-backup.log 2>&1

# Daily S3 upload backup - 12:10 PM
# 10 12 * * * /home/user/vmangos-docker/script/backup/04-s3-upload-backup.sh >> /home/user/vmangos-docker/script/crontab-logs/04-s3-upload-backup.log 2>&1

# Weekly backup retention cleanup - Sunday at 8:20 AM
20 8 * * 0 /home/user/vmangos-docker/script/backup/05-backup-retention-cleanup.sh >> /home/user/vmangos-docker/script/crontab-logs/05-backup-retention-cleanup.log 2>&1

####################
# Docker-Resources #
####################

# Hourly resource collection - 30 minutes past each hour
30 * * * * /home/user/vmangos-docker/script/docker-resources/01-docker-resources-collect.sh >> /home/user/vmangos-docker/script/crontab-logs/01-docker-resources-collect.log 2>&1

# Weekly resource adjustment - Sunday at 5:00 AM
0 5 * * 0 /home/user/vmangos-docker/script/docker-resources/02-docker-resources-adjust.sh >> /home/user/vmangos-docker/script/crontab-logs/02-docker-resources-adjust.log 2>&1

####################
# Faction-Balancer #
####################

# Hourly population data collection - 45 minutes past each hour
45 * * * * /home/user/vmangos-docker/script/faction-balancer/01-population-balance-collect.sh >> /home/user/vmangos-docker/script/crontab-logs/01-population-balance-collect.log 2>&1

# Daily faction XP rates update - 04:00 AM
00 4 * * * /home/user/vmangos-docker/script/faction-balancer/02-faction-specific-xp-rates-update.sh >> /home/user/vmangos-docker/script/crontab-logs/02-faction-specific-xp-rates-update.log 2>&1

########
# Logs #
########

# Weekly logs cleanup - Sunday at 12:00 PM
00 12 * * 0 /home/user/vmangos-docker/script/logs/01-vmangos-logs-cleanup.sh >> /home/user/vmangos-docker/script/crontab-logs/01-vmangos-logs-cleanup.log 2>&1
```

## Vanilla Reforged Links

- [Vanilla Reforged Website](https://vanillareforged.org/)
- [Vanilla Reforged Discord](https://discord.gg/KkkDV5zmPb)
- [My Patreon](https://www.patreon.com/vanillareforged)
- [Buy Me a Coffee](https://buymeacoffee.com/vanillareforged)

## Based Upon

- [tonymmm1 vmangos-docker](https://github.com/tonymmm1/vmangos-docker)
- [mserajnik vmangos-docker](https://github.com/mserajnik/vmangos-deploy)
