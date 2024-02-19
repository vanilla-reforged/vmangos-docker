# vmangos-docker

### Before you dive in

Secure your system by understanding the following information: https://github.com/chaifeng/ufw-docker.

the ufw commands you will need to secure your installation:

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

Lazycmd public access:

```sh
ufw route allow proto tcp from any to any port 80
ufw route allow proto tcp from any to any port 443
```

### ToDo

- cleanup root access on db container

### Dependencies

+ docker
+ docker compose 2
+ p7zip-full
+ A POSIX-compliant shell as well as various core utilities (such as `cp` and
  `rm`) if you intend to use the provided scripts to install, update and manage
  VMaNGOS

### Preface

This assumed client version is `5875` (patch `1.12.1`); if you want to set up
VMaNGOS to use a different version, modify the VMANGOS_CLIENT entry in the .env file accordingly.

The user that is used inside the persistent containers (VMANGOS_DATABASE, VMANGOS_REALMD, VMANGOS_MANGOS) has UID `1000` and GID `1000` by
default. You can adjust this, if needed; e.g., to match your host UID/GID.
This requires editing the entries VMANGOS_USER_ID and VMANGOS_GROUP_ID in the .env file.

Also please be aware that ./vol/client_data_extracted gets mounted directly into the mangos server to provide dbc and map data.

### Instructions vmangos

First, clone the repository and move into it.

```sh
git clone https://github.com/vanilla-reforged/vmangos-docker
cd vmangos-docker
```

At this point, you have to adjust the two configuration files in `./vol/configuration` as
well as `./.env` for your desired setup. The default setup will
only allow local connections (from the same machine). To make the server
public, it is required to change the `VMANGOS_REALM_IP` environment variable
in the .env file.

VMaNGOS also requires some data generated/extracted from the client to work
correctly. To generate that data with the provided shellscript, copy
the contents of your World of Warcraft client directory into
`./vol/client_data`.

Note that generating the required data will take many hours (depending on your
hardware). Some notices/errors during the generation are normal and nothing to
worry about.

Alternatively if you have already extracted the client data you may place it directly
in `./vol/client_data_extracted` and skip the "02-extract-client-data.sh" script.

To do the installation execute the scripts in order from 01 to 03.

```sh
./01-update-github-and-database.sh
./02-extract-client-data.sh
./03-compile-core.sh
```

create your vmangos network

```sh
docker network create vmangos-network
```

then start your environment

```sh
docker compose up -d
```

then create the database with the script 04.

```sh
./04-create-database-mangos.sh
```

If you used a custom mysql root passwort, you need to update your mangosd.conf and realmd.conf with that new password.

After the scripts have finished and you updated your mangosd.conf and realmd.conf, you should have a running installation and
can create your first account by attaching to the `vmangos_mangos` service:

```sh
docker attach vmangos_mangos
```

After attaching, create the account and assign an account level:

```sh
account create <account name> <account password>
account set gmlevel <account name> <account level> # see https://github.com/vmangos/core/blob/79efe80ae39d94a5e52b71179583509b1df75899/src/shared/Common.h#L184-L191
```

When you are done, detach from the Docker container by pressing
<kbd>Ctrl</kbd>+<kbd>P</kbd> and <kbd>Ctrl</kbd>+<kbd>Q</kbd>.

## Usage

### Starting and stopping VMaNGOS

VMaNGOS can be started and stopped using the following commands:

```sh
docker compose up -d
docker compose down
```

### Connecting

You will need to either edit the docker-compose.yml to bind ports directly to the docker host or use the traeffic reverse proxy under https://github.com/vanilla-reforged/traefik-vmangos-docker.

## Vanilla Reforged Links

Find and join us on the web https://vanillareforged.org/

Support our efforts on Patreon https://www.patreon.com/vanillareforged

## Links

- [vmangos](https://github.com/vmangos/core)
- [tonymmm1 vmangos-docker](https://github.com/tonymmm1/vmangos-docker)
- [mserajnik vmangos-docker](https://github.com/mserajnik/vmangos-deploy)
