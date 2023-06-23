Heavily inspired by Michael Serajnik @ repository https://sr.ht/~mser/vmangos-docker/ wouldn't have been possible without help from discord @ user 0x539.

---

# vmangos-docker

### Whats different

All variables can now be given in the .env file of the root directory, and are then passed either through the 00-build-extract.sh script or the docker-compose file to the corresponding commands and Dockerfiles.
Also Volumes now have their own directory for a better overview. Instructions below have been edited to reflect the changes to the process.

### Dependencies

+ [Docker][docker]
+ [Docker Compose][docker-compose]
+ A POSIX-compliant shell as well as various core utilities (such as `cp` and
  `rm`) if you intend to use the provided scripts to install, update and manage
  VMaNGOS

### Preface

This assumed client version is `5875` (patch `1.12.1`); if you want to set up
VMaNGOS to use a different version, modify the VMANGOS_CLIENT_VERSION entry in the .env file accordingly.

The user that is used inside the persistent containers (VMANGOS_DATABASE, VMANGOS_REALMD, VMANGOS_MANGOS) has UID `1000` and GID `1000` by
default. You can adjust this, if needed; e.g., to match your host UID/GID.
This requires editing the entries VMANGOS_USER_ID and VMANGOS_GROUP_ID in the .env file.

### Instructions

First, clone the repository and move into it.

```sh
user@local:~$ git clone https://github.com/flyingfrog23/vmangos-docker
user@local:~$ cd vmangos-docker

```

At this point, you have to adjust the two configuration files in `./volume/configuration` as
well as `./.env` for your desired setup. The default setup will
only allow local connections (from the same machine). To make the server
public, it is required to change the `VMANGOS_REALM_IP` environment variable
for the `vmangos_database` service in `./docker-compose.yml`. Simply replace
`127.0.0.1` with the server's WAN IP (or LAN IP, if you don't want to make it
accessible over the Internet).

VMaNGOS also requires some data generated/extracted from the client to work
correctly. To generate that data automatically during the installation, copy
the contents of your World of Warcraft client directory into
`./volume/client_data`.

After that, simply execute the script:

```sh
user@local:vmangos-docker$ ./00-build-extract.sh
```

Note that generating the required data will take many hours (depending on your
hardware). Some notices/errors during the generation are normal and nothing to
worry about.

Alternatively, if you have acquired the extracted/generated data previously,
you can place it directly into `./volume/client_data_extracted`, in which case the installer will
skip extracting/generating the data.

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

VMaNGOS can be started and stopped using the following scripts:

```sh
user@local:vmangos-docker$ docker-compose -d up
user@local:vmangos-docker$ docker-compose down
```

### REBUILDING - TODO

### Updating CORE - TODO

### Updating DATABASE without WORLD DB - TODO

### Updating DATABASE with WORLD DB - TODO

### Creating a database backup - TODO

### Extracting client data

If at any point after the initial installation you need to re-extract the
client data, you can do so by running the following script:

```sh
user@local:vmangos-docker$ ./00-extract-client.sh
```

Note that this will also remove any existing data in `./volume/client_data_extracted`, so make sure
to create a backup of that in case you want to save it.

## License

[AGPL-3.0-or-later](LICENSE) © Michael Serajnik

[vmangos]: https://github.com/vmangos/core
[tonymmm1-vmangos-docker]: https://github.com/tonymmm1/vmangos-docker
[Michael Serajnik vmangos-docker]: https://sr.ht/~mser/
[docker]: https://docs.docker.com/get-docker/
[docker-compose]: https://docs.docker.com/compose/install/


