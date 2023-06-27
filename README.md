Heavily inspired by Michael Serajnik @ repository https://sr.ht/~mser/vmangos-docker/ which in turn based his work on https://github.com/tonymmm1/vmangos-docker.

Wouldn't have been possible without help from the VMANGOS discord community and the user @0x539 in particular.

---

# vmangos-docker

### ToDO

- get generate-db-1.sql to use the env variable for setting the db pw (has to be edited manually atm)

### Whats different

- All variables can now be given in the .env file of the root directory.
- /src/ directory contains dependencies which are copied into the containers at build.
- /vol/ directory contains volumes mounted when the containers are running.
- Mapping directory path similar in host and container where apps don't expect a specific path.
- Non persistent containers (build, extractors) run with root.
- Scripts starting with 0X are meant for setup.
- Scripts starting with 1X are meant for rare update tasks.
- Scripts starting with 2X are meant for backup / maintenance task and are intended to be run as cron jobs.

The Instructions below have been edited to reflect the changes to setting up and using the project.

### Dependencies

+ [Docker][docker]
+ [Docker Compose][docker-compose]
+ p7zip
+ A POSIX-compliant shell as well as various core utilities (such as `cp` and
  `rm`) if you intend to use the provided scripts to install, update and manage
  VMaNGOS

### Preface

This assumed client version is `5875` (patch `1.12.1`); if you want to set up
VMaNGOS to use a different version, modify the VMANGOS_CLIENT entry in the .env file accordingly.

The user that is used inside the persistent containers (VMANGOS_DATABASE, VMANGOS_REALMD, VMANGOS_MANGOS) has UID `1000` and GID `1000` by
default. You can adjust this, if needed; e.g., to match your host UID/GID.
This requires editing the entries VMANGOS_USER_ID and VMANGOS_GROUP_ID in the .env file.

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
`./src/client_data`.

Note that generating the required data will take many hours (depending on your
hardware). Some notices/errors during the generation are normal and nothing to
worry about.

Alternatively if you have already extracted the client data you may place it directly
in /vol/server_data and skip the "03-extract-client-data.sh" script.

To do the installation execute the scripts in order from 01 to 04.

```sh
user@local:vmangos-docker$ .\01-clone-github.sh
user@local:vmangos-docker$ .\02-compile-core.sh
user@local:vmangos-docker$ .\03-extract-client-data.sh
user@local:vmangos-docker$ .\04-build-db-container.sh
```

After the installer has finished, you should have a running installation and
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

## Usage

### Starting and stopping VMaNGOS

VMaNGOS can be started and stopped using the following commands:

```sh
user@local:vmangos-docker$ docker-compose -d up
user@local:vmangos-docker$ docker-compose down
```

### REBUILDING - TODO

### Updating CORE - TODO

### Updating DATABASE without WORLD DB - TODO

### Updating DATABASE with WORLD DB - TODO

### Creating a database backup - TODO

### Extracting client data - TODO

## License

[AGPL-3.0-or-later](LICENSE) © Michael Serajnik

[vmangos]: https://github.com/vmangos/core
[tonymmm1-vmangos-docker]: https://github.com/tonymmm1/vmangos-docker
[Michael Serajnik vmangos-docker]: https://sr.ht/~mser/
[docker]: https://docs.docker.com/get-docker/
[docker-compose]: https://docs.docker.com/compose/install/


