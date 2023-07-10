Heavily inspired by Michael Serajnik @ repository https://sr.ht/~mser/vmangos-docker/ which in turn based his work on https://github.com/tonymmm1/vmangos-docker.

Wouldn't have been possible without help from the VMANGOS discord community and the user @0x539 in particular.

---

# vmangos-docker

### What is the idea

This is an attempt to make an easier to understand and set up VMANGOS environment for Docker, including a container running YesilCMS.
Feel free to use it or contribute.

### ToDO

- YesilCMS container
- 1X and 2X scripttest

### Differences to Michael Serajnik's vmangos for docker (@repository https://sr.ht/~mser/vmangos-docker/)

- All variables can now be given in the .env file of the root directory.
- All volumes are in the ./vol directory.
- Directory paths for volumes are similar in host and container, where apps don't expect a specific path within the container.
- Non-persistent containers run with root.
- No more copying of data to containers, instead volumes are used.
- Tasks have been split in multiple scripts for easier troubleshooting.
   - Scripts starting with 0X are meant for setup.
   - Scripts starting with 1X are meant for update and recreation tasks.
   - Scripts starting with 2X are meant for backup and maintenance tasks and are intended to be run as cron jobs.

### Dependencies

+ docker
+ docker-compose
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

### Instructions

First, clone the repository and move into it.

```sh
user@local:~$ git clone https://github.com/flyingfrog23/vmangos-docker
user@local:~$ cd vmangos-docker

```

At this point, you have to adjust the two configuration files in `./vol/configuration` as
well as `./.env` for your desired setup. The default setup will
only allow local connections (from the same machine). To make the server
public, it is required to change the `VMANGOS_REALM_IP` environment variable
for the `vmangos_database` service in `./docker-compose.yml`. Simply replace
`127.0.0.1` with the server's WAN IP (or LAN IP, if you don't want to make it
accessible over the Internet).

VMaNGOS also requires some data generated/extracted from the client to work
correctly. To generate that data with the provided shellscript, copy
the contents of your World of Warcraft client directory into
`./vol/client_data`.

Note that generating the required data will take many hours (depending on your
hardware). Some notices/errors during the generation are normal and nothing to
worry about.

Alternatively if you have already extracted the client data you may place it directly
in `./vol/client_data_extracted` and skip the "03-extract-client-data.sh" script.

To do the installation execute the scripts in order from 01 to 03.

```sh
user@local:vmangos-docker$ .\01-preparations-github-and-database.sh
user@local:vmangos-docker$ .\02-compile-core.sh
user@local:vmangos-docker$ .\03-extract-client-data.sh
```
then start your environment

```sh
user@local:vmangos-docker$ docker compose up -d
```

then create the databases with the scripts 04 and 05.

```sh
user@local:vmangos-docker$ .\04-create-database-mangos.sh
user@local:vmangos-docker$ .\05-create-database-yesilcms.sh
```

After the scripts have finished, you should have a running installation and
can create your first account by attaching to the `vmangos_mangos` service:

```sh
user@local:vmangos-docker$ docker attach vmangos_mangos
```

After attaching, create the account and assign an account level:

```sh
account create <account name> <account password>
account set gmlevel <account name> <account level> # see https://github.com/vmangos/core/blob/79efe80ae39d94a5e52b71179583509b1df75899/src/shared/Common.h#L184-L191
```

When you are done, detach from the Docker container by pressing
<kbd>Ctrl</kbd>+<kbd>P</kbd> and <kbd>Ctrl</kbd>+<kbd>Q</kbd>.

ToDo for configuring yesilcms, expose

## Usage

### Starting and stopping VMaNGOS

VMaNGOS can be started and stopped using the following commands:

```sh
user@local:vmangos-docker$ docker compose up -d
user@local:vmangos-docker$ docker compose down
```

## License

[AGPL-3.0-or-later](LICENSE)

[vmangos]: https://github.com/vmangos/core
[tonymmm1-vmangos-docker]: https://github.com/tonymmm1/vmangos-docker
[Michael Serajnik vmangos-docker]: https://sr.ht/~mser/
