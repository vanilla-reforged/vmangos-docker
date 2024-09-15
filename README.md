
## A Docker setup for VMaNGOS.

## Todo

- Use docker swarm to leverage docker secrets.

## Dependencies

- Azure-CLI
- Docker
- Docker compose 2
- p7zip-full
- A POSIX-compliant shell as well as various core utilities (such as `cp` and `rm`) if you intend to use the provided scripts to install, update, and manage VMaNGOS.

## Security

Secure your system by understanding the following information: [ufw-docker](https://github.com/chaifeng/ufw-docker).

The ufw commands you will need to secure your installation:

### Management:

```sh
ufw allow from [your client ip]
ufw route allow proto tcp from [your client ip] to any
```

### Vmangos public access:

```sh
ufw route allow proto tcp from any to any port 3724
ufw route allow proto tcp from any to any port 8085
```

## Docker Setup

The assumed client version is `5875` (patch `1.12.1`); if you want to set up VMaNGOS to use a different version, modify the `VMANGOS_CLIENT` entry in the `.env` file accordingly.

The user that is used inside the persistent containers (VMANGOS_DATABASE, VMANGOS_REALMD, VMANGOS_MANGOS) has UID `1000` and GID `1000` by default. You can adjust this if needed; e.g., to match your host UID/GID. This requires editing the entries `VMANGOS_USER_ID` and `VMANGOS_GROUP_ID` in the `.env` file.

Also, please be aware that `./vol/client-data-extracted` gets mounted directly into the mangos server to provide dbc and map data.

### Clone the Repository

```sh
git clone https://github.com/vanilla-reforged/vmangos-docker
```

### Move into the repository and make all scripts executable

```sh
cd vmangos-docker
find ./* -type f -iname "*.sh" -exec chmod +x {} \;
```


### Adjust .env Files

Adjust the .env files for your desired setup:

- `.env` For Docker Compose
- `.env-script` For Scripts
- `.env-vmangos-build` For compiler image build / to set the cmake options.

To make the server public, change the `VMANGOS_REALM_IP` environment variable in the `.env-script` file.

### Generate/Extract Client Data

Copy the contents of your World of Warcraft client directory into `./vol/client-data`. Generating the required data will take many hours. If you have already extracted the client data, place it in `./vol/client-data-extracted` and skip the "03-extract-client-data.sh" script.

### Installation

Install the dependencies with the script:
```sh
00-setup-dependencies.sh
```

Execute the scripts in order:

```sh
./01-create-dockeruser-and-set-permissions.sh
./02-update-github-and-database.sh
./03-compile-core.sh
./04-extract-client-data.sh
```

Set the ressource limits for the vmangos containers to avoid OOME crashes, the values are adjustable in the script, minimal values are set in the script to ensure the containers start even on shitboxes.

Attention: If Swap Limit Support is not enabled in /etc/default/grub this script will automatically do it and reboot the server to activate it.

```sh
./05-set-ressource-limits.sh
```

Create the vmangos network:

```sh
docker network create vmangos-network
```

Start your environment:

```sh
docker compose up -d
```

Create the database:

```sh
./06-create-database-mangos.sh
```

### Configure MySQL Password

Update `mangosd.conf` and `realmd.conf` with your MySQL root password if changed.

### Create Account

Attach to the `vmangos_mangos` service:

```sh
docker attach vmangos-mangos
```

Create the account:

```sh
account create <account name> <account password>
account set gmlevel <account name> <account level>
```

Detach from the Docker container:

Press <kbd>Ctrl</kbd>+<kbd>P</kbd> and <kbd>Ctrl</kbd>+<kbd>Q</kbd>.

### Clear MySQL Root Password

Clear the MySQL root password and restart the database:

```sh
./07-remove-root-env-database.sh
```

## Starting and Stopping VMaNGOS

```sh
docker compose down
docker compose up -d
```

## Scripts

### Manual Tasks

- `./11-import-world-db-migrations.sh`

  - Import new migrations.
- `./12-recreate-world-db.sh`
  - Recreate the world database.

- `./13-recompile-core.sh`
  - Recompile the core.

### Cronjobs

- `./21-collect-ressource-usage.sh`
   - Collect ressource usage for database, mangos and realmd containers.

- `./22-adjust-ressource-limits.sh`
   - Adjust ressource allocations in docker-compose.yml based on 7 day averages of the Data collected with `25-collect-ressource-usage.sh`.

- `./31-database-backup.sh` - Backup dynamic databases.
  - Daily Full Backup
  - Configurable Incremental Backups
  - Weekly Log Database truncation
  - S3 Offload - Attention: API calls/immutability are a financial risk. You must know what you are doing with this.
  - Cleanup of old local backups
 
- `./32-world-database-backup.sh`
  - Backup world database.

- `./33-logs-directory-cleanup.sh`
  - Cleanup mangos logs older than 3 days, honor logs older than 2 weeks, realmd logs older than 1 week. 

- `./41-collect-population-balance.sh`
  - Collect faction balance data.

- `./42-faction-specific-xp-rates.sh`
  - Set faction-specific XP rates and restart server to activate them. Requires core change [Vanilla Reforged - Faction specific XP rates](https://github.com/vmangos/core/commit/6a91ac278954431f615583ddf98137efede74232).

#### Edit the crontab using the command below:
```sh
crontab -e
```

#### Add the following lines to the crontab file, change the paths to fit your installation:

```sh
# Runs every hour on the hour
0 * * * * /path/to/21-collect-ressource-usage.sh >> /path/to/logs/21-collect-ressource-usage.log 2>&1

# Runs weekly on Sunday at 4:00 AM
0 4 * * 0 /path/to/22-adjust-ressource-limits.sh >> /path/to/logs/22-adjust-ressource-limits.log 2>&1

# Runs every hour on the hour
0 * * * * /path/to/31-database-backup.sh >> /path/to/logs/31-database-backup.log 2>&1

# Runs weekly on Sunday at 5:00 AM if outcommented
# 0 5 * * 0 /path/to/32-world-database-backup.sh >> /path/to/logs/32-world-database-backup.log 2>&1

# Runs daily at 3:00 AM
0 3 * * * /path/to/33-logs-directory-cleanup.sh >> /path/to/logs/33-logs-directory-cleanup.log 2>&1

# Runs every hour on the hour
0 * * * * /path/to/41-collect-population-balance.sh >> /path/to/logs/41-collect-population-balance.log 2>&1

# Runs daily at 5:00 AM
0 5 * * * /path/to/42-faction-specific-xp-rates.sh >> /path/to/logs/42-faction-specific-xp-rates.log 2>&1
```

## Vanilla Reforged Links

- [Vanilla Reforged Website](https://vanillareforged.org/)
- [Vanilla Reforged Discord](https://discord.gg/KkkDV5zmPb)
- [Vanilla Reforged Patreon](https://www.patreon.com/vanillareforged)

## Based Upon

- [tonymmm1 vmangos-docker](https://github.com/tonymmm1/vmangos-docker)
- [mserajnik vmangos-docker](https://github.com/mserajnik/vmangos-deploy)
