
# VMaNGOS Docker Setup

## A Docker setup for VMaNGOS.

## Todo

- Use docker swarm to leverage docker secrets.

## Dependencies

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
cd vmangos-docker
```

### Adjust .env Files

Adjust the .env files for your desired setup:

- `.env` For Docker Compose
- `.env-script` For Scripts
- `.env-vmangos-build` For compiler image build / to set the cmake options.

To make the server public, change the `VMANGOS_REALM_IP` environment variable in the `.env-vmangos-database` file.

### Generate/Extract Client Data

Copy the contents of your World of Warcraft client directory into `./vol/client-data`. Generating the required data will take many hours. If you have already extracted the client data, place it in `./vol/client-data-extracted` and skip the "03-extract-client-data.sh" script.

### Installation

Execute the scripts in order:

```sh
./01-create-dockeruser-and-set-permissions.sh
./02-update-github-and-database.sh
./03-compile-core.sh
./04-extract-client-data.sh
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
./05-create-database-mangos.sh
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
06-remove-root-env-database.sh
```

## Starting and Stopping VMaNGOS

```sh
docker compose down
docker compose up -d
```
## Mangos and realmd logs

Update your ```mangosd.conf```
/opt/vmangos/logs
/opt/vmangos/honor

and ```realmd.conf``` f
/opt/vmangos/logs


## Scripts

### Manual Tasks

- `11-import-world-db-migrations.sh` - Import new migrations.
- `12-recreate-world-db.sh` - Recreate the world database.
- `13-recompile-core.sh` - Recompile the core.

### Cronjobs

- `21-database-backup.sh` - Backup dynamic databases.
- `22-world-database-backup.sh` - Backup world database.
- `23-backup-directory-cleanup.sh` - Cleanup old backups.
- `24-logs-directory-cleanup.sh` - Cleanup old logs.
- `30-collect-population-balance.sh` - Collect faction balance data.
- `31-faction-specific-xp-rates.sh` - Set faction-specific XP rates.

## Vanilla Reforged Links

- [Vanilla Reforged Website](https://vanillareforged.org/)
- [Vanilla Reforged Discord](https://discord.gg/KkkDV5zmPb)
- [Vanilla Reforged Patreon](https://www.patreon.com/vanillareforged)

## Based Upon

- [tonymmm1 vmangos-docker](https://github.com/tonymmm1/vmangos-docker)
- [mserajnik vmangos-docker](https://github.com/mserajnik/vmangos-deploy)
