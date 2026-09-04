# Kroger Tracker API & CLI Interface Reference

This document details the command-line interface (CLI) specifications, input parameter schemas, environment variable envelopes, output formatting, exit codes, and health probe interfaces for `kroger_tracker`.

---

## Overview

`kroger_tracker` operates primarily through Linux Shell / CLI interfaces and automated lifecycle management hooks.

- **Execution Protocols**: Local POSIX/Bash process execution.
- **Base Host Directory (`TARGET_BASE_DIR`)**: `/home/james/sprillex/docker`
- **Base Persistent Data Directory (`DATA_BASE_DIR`)**: `/home/james/sprillex/docker/docker_data`
- **Port Allocation Range**: `1024`–`65535` (excluding ports listed in `docker_tools/common_ports_do_not_use.csv`).

---

## Authentication & Credential Workflows

The tools themselves do not manage remote authentication tokens directly. Instead, they leverage host-level Git credentials and SSH keys when interacting with remote repositories.

- **Git Repositories**: When cloning private repositories, user credentials (e.g., Personal Access Tokens, SSH keys, or Git credential helpers) must be configured in the host environment prior to executing `clone_docker.sh`.
- **Environment Variable Configuration**: Service credentials and secrets are managed via injected `.env` files located inside each cloned project directory (`/home/james/sprillex/docker/<project_name>/.env`).

---

## Standard Output Envelopes & Exit Codes

### Console Log Envelope Format

All stdout/stderr logs emitted by `clone_docker.sh` and generated `update.sh` scripts use standard prefix labels with optional ANSI color coding:

```text
[INFO]  Descriptive information message
[WARN]  Warning message (non-fatal condition or fallback action)
[ERROR] Error message indicating failure or mandatory requirement missing
```

**Concrete Example Output**:

```text
INFO: Project Name: my-app
INFO: Target Dir:   /home/james/sprillex/docker/my-app
INFO: Data Dir:     /home/james/sprillex/docker/docker_data/my-app
INFO: Non-interactive mode: Port 5000 is available.
Injected SPRILLEX_DATA_PATH=/home/james/sprillex/docker/docker_data/my-app into .env
Injected SERVICE_PORT=5000 into .env
```

### Exit Codes

| Exit Code | Meaning | Common Triggers |
| :--- | :--- | :--- |
| `0` | Success | Operation completed successfully or help displayed. |
| `1` | Error / Aborted | Invalid command arguments, directory collision, invalid port, taken port on startup, or non-interactive missing required parameter. |

---

## Environment Variable Envelope Schema (`.env`)

`clone_docker.sh` reads and injects standard environment variables into the project's `.env` file.

### Injected Variables Schema

| Variable Name | Type | Required | Description | Example / Default |
| :--- | :--- | :--- | :--- | :--- |
| `SPRILLEX_DATA_PATH` | `string` | **Yes** | Absolute path to persistent host data directory. | `/home/james/sprillex/docker/docker_data/my-app` |
| `SERVICE_PORT` | `integer` | Optional | Allocated host port bound to the container service. | `5000` |
| `HEALTHCHECK_URL` | `string` | Optional | Absolute URL used by `update.sh` to poll container health. | `http://127.0.0.1:5000/health` |

### Concrete `.env` Envelope Example

```env
# Sprillex standard persistent data path
SPRILLEX_DATA_PATH=/home/james/sprillex/docker/docker_data/my-app

# Selected Server Port
SERVICE_PORT=5000

# Health Check Endpoint
HEALTHCHECK_URL=http://127.0.0.1:5000/health
```

---

## Command Interfaces & Endpoints

### 1. `docker_tools/clone_docker.sh`

Clones a Docker Git repository, initializes persistent data directories, injects environment variables, selects an available server port, and generates `update.sh`.

#### Command Syntax

```bash
./docker_tools/clone_docker.sh <GITHUB_URL> [OPTIONS]
```

#### Parameters & Flags

| Flag / Option | Type | Required / Optional | Description |
| :--- | :--- | :--- | :--- |
| `GITHUB_URL` | `string` (Positional) | **Required** (or prompted interactively) | URL ending with `.git` (e.g. `https://github.com/user/repo.git`). |
| `-y`, `--yes` | `boolean` (Flag) | Optional | Enables non-interactive mode. Requires `GITHUB_URL` as argument or input. |
| `-h`, `--help` | `boolean` (Flag) | Optional | Displays usage instructions and exits with `0`. |

#### Interactive Input Prompts

When executed interactively without flags:
1. `GitHub Repository URL`: Repository URL if not passed as positional argument.
2. `Require Server Port?`: `y`/`n` prompt determining whether to allocate `SERVICE_PORT`.
3. `Service Port`: Requested port number (1024-65535). Automatically validated against system port usage and forbidden ports list.
4. `Health Check URL`: Optional URL to test via `curl` post-startup.

#### Success Response Behavior (`0`)

1. Repository cloned to `/home/james/sprillex/docker/<project_name>`.
2. Persistent data folder created at `/home/james/sprillex/docker/docker_data/<project_name>`.
3. Variables (`SPRILLEX_DATA_PATH`, `SERVICE_PORT`, `HEALTHCHECK_URL`) injected into `.env`.
4. Executable `update.sh` generated in `/home/james/sprillex/docker/<project_name>/update.sh`.
5. Docker containers started if confirmed.

#### Known Error Responses (`1`)

- **Invalid URL**: URL does not end with `.git`.
  ```text
  Error: The URL should end with '.git'.
  ```
- **Target Directory Exists**: `/home/james/sprillex/docker/<project_name>` already exists on host.
  ```text
  Error: Directory /home/james/sprillex/docker/my-app already exists.
  ```
- **Port Conflict / Forbidden**: Requested or fallback port is in `common_ports_do_not_use.csv` or in use by another process.
  ```text
  ERROR: Port 8080 is in the forbidden list (./docker_tools/common_ports_do_not_use.csv).
  ```

---

### 2. Generated Lifecycle Interface (`update.sh`)

Generated inside every cloned repository at `/home/james/sprillex/docker/<project_name>/update.sh`. Managed by `universal_update_manager.sh` or invoked directly.

#### Command Syntax

```bash
./update.sh [OPTIONS]
```

#### Options & Flag Parameters

| Flag | Long Option | Type | Description |
| :--- | :--- | :--- | :--- |
| `-u` | `--update` | Flag | Pulls latest code, backs up data directory to `.tar.gz`, rebuilds images, and restarts containers. |
| `-m` | `--main` | Flag | Fetches and checks out remote `origin/HEAD` (main/master) branch before updating. |
| `-n` | `--newest` | Flag | Fetches and checks out the newest remote branch by committer date before updating. |
| `-s` | `--status` | Flag | Runs `docker compose ps` to print container status. |
| `-l` | `--logs` | Flag | Runs `docker compose logs --tail=100 -f` to stream container logs. |
| `-r` | `--restart` | Flag | Restarts containers via `docker compose down` and `docker compose up -d`. |
| `-c` | `--settings` | Flag | Displays command to edit `.env` file via text editor (`nano .env`). |
| `-y` | `--yes` | Flag | Runs non-interactively without prompting. |
| `-h` | `--help` | Flag | Displays CLI help message. |

#### Interactive Menu Mode

If executed with no arguments in interactive mode, an interactive terminal menu prompt appears:

```text
--- Sprillex: my-app Update Menu ---
1) Status
2) Logs
3) Restart
4) Update
5) Quit
Select an option:
```

---

## Health Check Probe Protocol

When `HEALTHCHECK_URL` is defined in `.env`, `update.sh` executes `wait_for_healthcheck()` following container startup (`docker compose up -d`).

### Probe Behavior & Specification

- **HTTP Verb**: `GET`
- **Probe Command**: `curl -f -s -o /dev/null "$HEALTHCHECK_URL"`
- **Timeout / Retry Interval**: 30 attempts, 1 second pause between retries (Maximum 30 seconds wait).
- **Success Criteria**: HTTP Response status code `200` OK (or any `2xx` success code supported by `curl -f`).

#### Success Health Check Log Output

```text
[INFO] Waiting for service to initialize (up to 30s)...
......
[INFO] SUCCESS: Service is responding at http://127.0.0.1:5000/health
```

#### Failure / Timeout Log Output

```text
[INFO] Waiting for service to initialize (up to 30s)...
..............................
[WARN] WARNING: Service failed to respond at http://127.0.0.1:5000/health after 30 seconds
[WARN] Check logs with: docker compose logs
```

---

## Querying & Log Inspection

`update.sh` provides standard parameters for inspecting logs and filtering container outputs.

- **Tail Length**: Default log query fetches the last 100 lines (`--tail=100`).
- **Follow Mode**: Streaming mode enabled (`-f`).

```bash
# Query container status
./update.sh -s

# Stream tail logs
./update.sh -l
```
