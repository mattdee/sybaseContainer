# Sybase Container Management Script

`sybaseContainer.sh` is a Bash utility for managing a local Sybase container with either **Docker** or **Podman**. It supports both command-line usage for automation and an interactive menu for day-to-day container management.

The script uses the [`datagrip/sybase:16.0`](https://hub.docker.com/r/datagrip/sybase) image by default and exposes Sybase on port `5000`.

## Features

- Start a new Sybase container
- Restart an existing stopped container
- Stop the running container
- Remove the container
- Show container status and mapped ports
- Open a Bash shell in the container
- Open a root shell in the container
- Open an interactive Sybase `isql` session
- Copy files into and out of the container
- Use Docker or Podman with the same script
- Override container settings with environment variables
- Interactive menu mode when no command is provided

## Requirements

- Docker or Podman
- Internet access for the first image pull
- Bash

For Podman on macOS, make sure the Podman machine is initialized and running:

```bash
podman machine init
podman machine start
```

## Installation

Clone or download the script, then make it executable:

```bash
chmod +x sybaseContainer.sh
```

## Usage

### CLI Mode

```bash
./sybaseContainer.sh start      # Start or restart the Sybase container
./sybaseContainer.sh stop       # Stop the running Sybase container
./sybaseContainer.sh restart    # Restart the Sybase container
./sybaseContainer.sh status     # Show container status and mapped ports
./sybaseContainer.sh bash       # Open a Bash shell in the container
./sybaseContainer.sh root       # Open a root shell in the container
./sybaseContainer.sh sql        # Open isql as the default application user
./sybaseContainer.sh adminsql   # Open isql as the default admin user
./sybaseContainer.sh remove     # Remove the Sybase container
./sybaseContainer.sh copyin     # Copy a local file into the container
./sybaseContainer.sh copyout    # Copy a file from the container to the host
./sybaseContainer.sh help       # Show help
```

### Interactive Menu

Run the script without arguments:

```bash
./sybaseContainer.sh
```

The menu provides options to start, stop, restart, inspect, remove, and access the container.

## Docker and Podman Support

By default, the script uses Docker if it is available. If Docker is not found, it falls back to Podman.

To explicitly choose an engine, set `CONTAINER_ENGINE`:

```bash
CONTAINER_ENGINE=docker ./sybaseContainer.sh start
CONTAINER_ENGINE=podman ./sybaseContainer.sh start
```

You can use the same override with any command:

```bash
CONTAINER_ENGINE=podman ./sybaseContainer.sh status
CONTAINER_ENGINE=docker ./sybaseContainer.sh bash
```

## Configuration

The script can be configured with environment variables.

| Variable | Default | Description |
| --- | --- | --- |
| `CONTAINER_ENGINE` | Auto-detect | Container engine to use: `docker` or `podman` |
| `SYBASE_CONTAINER` | `mysybase` | Container name |
| `SYBASE_IMAGE` | `datagrip/sybase:16.0` | Container image |
| `SYBASE_PORT` | `5000` | Host port |
| `SYBASE_CONTAINER_PORT` | `5000` | Container port |
| `SYBASE_NETWORK` | `sybasenet` | Docker or Podman network name |
| `SYBASE_SERVER` | `MYSYBASE` | Sybase server name used by `isql` |
| `SYBASE_LOGIN` | `matt` | SQL user for `sql` |
| `SYBASE_LOGIN_PASSWORD` | `guest1234` | SQL password for `sql` |
| `SYBASE_LOGIN_DB` | `testdb` | Database for `sql` |
| `SYBASE_ADMIN_USER` | `sa` | SQL admin user for `adminsql` |
| `SYBASE_ADMIN_PASSWORD` | `myPassword` | SQL admin password for `adminsql` |

Examples:

```bash
SYBASE_CONTAINER=devsybase ./sybaseContainer.sh start
SYBASE_PORT=15000 ./sybaseContainer.sh start
CONTAINER_ENGINE=podman SYBASE_PORT=15000 ./sybaseContainer.sh start
SYBASE_LOGIN=appuser SYBASE_LOGIN_PASSWORD=appuser123 ./sybaseContainer.sh sql
```

## SQL Access

The container image includes Sybase command-line tooling. After the container is running, open an interactive `isql` session with:

```bash
./sybaseContainer.sh sql
```

Before connecting, the script uses the configured admin login to ensure the requested `SYBASE_LOGIN` exists and is mapped into `SYBASE_LOGIN_DB`. This allows each user to choose their own SQL login:

```bash
SYBASE_LOGIN=matt SYBASE_LOGIN_PASSWORD=MyPassword123 ./sybaseContainer.sh sql
```

If `SYBASE_LOGIN_DB` does not exist, the script creates it first. Database names should contain only letters, numbers, and underscores.

By default, this connects with:

| Setting | Value |
| --- | --- |
| Server | `MYSYBASE` |
| User | `matt` |
| Password | `guest1234` |
| Database | `testdb` |

For admin access, use:

```bash
./sybaseContainer.sh adminsql
```

By default, this connects with:

| Setting | Value |
| --- | --- |
| Server | `MYSYBASE` |
| User | `sa` |
| Password | `myPassword` |

Inside `isql`, terminate SQL batches with `go`:

```sql
select @@version
go

sp_helpdb
go
```

You can also connect from an external SQL client such as DataGrip or DBeaver:

| Setting | Value |
| --- | --- |
| Host | `127.0.0.1` |
| Port | `5000` |
| Database | `testdb` |
| User | `matt` |
| Password | `guest1234` |

Example JDBC URLs:

```text
jdbc:jtds:sybase://127.0.0.1:5000/testdb
jdbc:sybase:Tds:127.0.0.1:5000/testdb
```

## Default Container Run Behavior

On first start, the script creates a network and runs the container with settings equivalent to:

```bash
docker run -d -t \
  --network=sybasenet \
  -p 5000:5000 \
  --name mysybase \
  datagrip/sybase:16.0
```

With Podman, the same options are passed to `podman run`.

## Common Workflows

Start Sybase:

```bash
./sybaseContainer.sh start
```

Check status:

```bash
./sybaseContainer.sh status
```

Open a shell:

```bash
./sybaseContainer.sh bash
```

Open SQL access:

```bash
./sybaseContainer.sh sql
```

Stop Sybase:

```bash
./sybaseContainer.sh stop
```

Remove the container:

```bash
./sybaseContainer.sh remove
```

## Notes

- The script manages a single named container by default: `mysybase`.
- If the container already exists but is stopped, `start` restarts it.
- If the container is already running, `start` reports the current status and mapped ports.
- File copy operations place inbound files in `/tmp` inside the container and outbound files in `/tmp` on the host.
- This script does not remove images or volumes automatically.
- The explicit `16.0` tag is used because it was verified with `isql`; the untagged `latest` image may behave differently depending on platform.

## License

This script is provided as-is. For the Sybase container image licensing and usage details, review the image publisher's terms on Docker Hub.
