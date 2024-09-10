### vmangos-docker

A Docker setup for VMaNGOS.

### Todo

Use docker swarm to leverage docker secrets.

### dependencies

- Docker
- Docker compose 2
- p7zip-full
- A POSIX-compliant shell as well as various core utilities (such as `cp` and `rm`) if you intend to use the provided scripts to install, update, and manage VMaNGOS.

### security

Secure your system by understanding the following information: [ufw-docker](https://github.com/chaifeng/ufw-docker).

The ufw commands you will need to secure your installation:

Management:

```sh
ufw allow from [your client ip]
ufw route allow proto tcp from [your client ip] to any
```

Vmangos public access:

```sh
ufw route allow proto tcp from any to any port 3724
ufw route allow proto tcp from any to any port 8085
```

### docker setup

The assumed client version is `5875` (patch `1.12.1`); if you want to set up VMaNGOS to use a different version, modify the `VMANGOS_CLIENT` entry in the `.env` file accordingly.

The user that is used inside the persistent containers (VMANGOS_DATABASE, VMANGOS_REALMD, VMANGOS_MANGOS) has UID `1000` and GID `1000` by default. You can adjust this if needed; e.g., to match your host UID/GID. This requires editing the entries `VMANGOS_USER_ID` and `VMANGOS_GROUP_ID` in the `.env` file.

Also, please be aware that `./vol/client-data-extracted` gets mounted directly into the mangos server to provide dbc and map data.

First, clone the repository and move into it:

```sh
git clone https://github.com/vanilla-reforged/vmangos-docker
cd vmangos-docker
```

At this point, you have to adjust the .env files for your desired setup:

`.env` For Docker Compose
`.env-script` For Scripts
`.env-vmangos-build` For compiler image build / to set the cmake options.

The default setup will only allow local connections (from the same machine). To make the server public, it is required to change the `VMANGOS_REALM_IP` environment variable in the `.env-vmangos-database` file.

VMaNGOS also requires some data generated/extracted from the client to work correctly. To generate that data with the provided shell script, copy the contents of your World of Warcraft client directory into `./vol/client-data`.

Note that generating the required data will take many hours (depending on your hardware). Some notices/errors during the generation are normal and nothing to worry about.

Alternatively, if you have already extracted the client data, you may place it directly in `./vol/client-data-extracted` and skip the "03-extract-client-data.sh" script.

To do the installation, execute the scripts in order from 01 to 04:

```sh
./01-create-dockeruser-and-set-permissions.sh
./02-update-github-and-database.sh
./03-compile-core.sh
./04-extract-client-data.sh
```

Then create the vmangos network:

```
docker network create vmangos-network
```

Then start your environment:

```sh
docker compose up -d
```

Then create the database with the script 04:

```sh
./05-create-database-mangos.sh
```

If you used a custom MySQL root password, you need to update your `mangosd.conf` and `realmd.conf` with that new password.

After the scripts have finished and you updated your configuration files, you should have a running installation and can create your first account by attaching to the `vmangos_mangos` service:

```sh
docker attach vmangos-mangos
```

After attaching, create the account and assign an account level:

```sh
account create <account name> <account password>
account set gmlevel <account name> <account level> # see https://github.com/vmangos/core/blob/79efe80ae39d94a5e52b71179583509b1df75899/src/shared/Common.h#L184-L191
```

When you are done, detach from the Docker container by pressing <kbd>Ctrl</kbd>+<kbd>P</kbd> and <kbd>Ctrl</kbd>+<kbd>Q</kbd>.

Finally, clear the mysql root password from the .env variable and restart the database container by executing:

```sh
06-remove-root-env-database.sh
```

### starting and stopping vmangos

Vmangos can be stopped and stated using the following commands:

```sh
docker compose down
docker compose up -d
```

### scripts

scripts for manual tasks

11-import-world-db-migrations.sh can be used to import new migrations after running 02-update-github-and-database.sh

12-recreate-world-db.sh can be used to recreate the world database if needed

13-recompile-core.sh allows you to recompile the core without touching the database

scripts for cronjobs

21-database-backup.sh, backups the more dynamic characters, reaqlmd and logs dbs

22-world-database-backup.sh backups the more static world database

23-backup-directory-cleanup.sh, deletes old backups (7days adjust as needed)

24-collect-population-balance.sh, collect horde/alliance ratio in your preferd timerframe (for example hourly)

25-faction-specific-xp-rates.sh, set the xp rates and restart the server to make them active (necessitates changes in core sett github.com/vanilla-reforged)

## vanilla reforged links
- [Vanilla Reforged Website](https://vanillareforged.org/)
- [Vanilla Reforged Discord](https://discord.gg/KkkDV5zmPb)
- [Vanilla Reforged Patreon](https://www.patreon.com/vanillareforged)

## this work is based upon these projects
- [tonymmm1 vmangos-docker](https://github.com/tonymmm1/vmangos-docker)
- [mserajnik vmangos-docker](https://github.com/mserajnik/vmangos-deploy)
