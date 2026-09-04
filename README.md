# kroger_tracker

`kroger_tracker` is an infrastructure and lifecycle management toolkit designed for automated cloning, persistence management, dynamic port allocation, and automated updates of Docker applications within the Sprillex ecosystem. It provides CLI utilities to streamline container deployment, isolate persistent host storage, avoid port collisions, and enforce uniform AI design and operational standards across hosted services.

## Features

- **Automated Docker Project Cloning**: Clones Git repositories into designated target directories (`TARGET_BASE_DIR`).
- **Data Isolation & Persistence**: Maps persistent application volumes to an out-of-tree central data folder (`DATA_BASE_DIR`), avoiding accidental data loss during Git resets or image rebuilds.
- **Intelligent Port Allocation**: Scans system ports via `lsof`/`ss`/`netstat` and checks against a blacklist (`common_ports_do_not_use.csv`) to automatically assign collision-free ports.
- **Automated Update Script Generation**: Generates a standardized, Sprillex-compliant `update.sh` script inside each cloned repository for seamless lifecycle management.
- **Health Check Probe Verification**: Verifies container health after startup using configurable health check URLs and retry polling.
- **Ecosystem & Design Guidance**: Enforces dark mode design standards (`AI_MANUAL_DESIGN_STANDARDS.md`) and Docker operational rules (`AI_MANUAL_DOCKER_TOOLS.md`).

## Tech Stack & Architecture

- **Runtime Environment**: Linux / Unix Bash (v4.0+)
- **Containerization**: Docker & Docker Compose
- **Network & System Tools**: `lsof`, `ss`, `netstat`, `curl`, `tar`, `sed`, `grep`
- **Configuration & Secrets**: Dotenv (`.env`) dynamic injection

```
+--------------------------------------------------------------------------+
|                              kroger_tracker                              |
|                                                                          |
|   +--------------------------+         +-----------------------------+   |
|   | docker_tools/            |         | Ecosystem Manuals           |   |
|   |  - clone_docker.sh       |         |  - AI_MANUAL_DESIGN_...     |   |
|   |  - common_ports_...csv   |         |  - AI_MANUAL_DOCKER_...     |   |
|   +------------+-------------+         +-----------------------------+   |
+----------------|---------------------------------------------------------+
                 | Clones & Configures
                 v
+--------------------------------------------------------------------------+
| Host Target Directory (/home/james/sprillex/docker)                      |
|                                                                          |
|  +---------------------------+        +-------------------------------+  |
|  | <project_name>/           |        | docker_data/<project_name>/   |  |
|  |  - .env (Injected config) |        |  - Persistent Application     |  |
|  |  - update.sh (Generated)  |=======>|    Data & Backups             |  |
|  |  - docker-compose.yml     |        |                               |  |
|  +---------------------------+        +-------------------------------+  |
+--------------------------------------------------------------------------+
```

## Repository Layout

```
.
├── AI_MANUAL_DESIGN_STANDARDS.md  # Dark mode, typography, and UI design standards
├── AI_MANUAL_DOCKER_TOOLS.md      # Docker operational rules and integration guides
├── README.md                      # Project overview and system documentation
├── API.md                         # Detailed API reference for CLI tools & lifecycle interfaces
└── docker_tools/
    ├── clone_docker.sh            # Main deployment and lifecycle script generator
    └── common_ports_do_not_use.csv # Blacklist of reserved/common host ports
```

## Prerequisites & Setup

### Requirements

Ensure the following tools are installed on your host system:
- `bash` (4.0+)
- `git`
- `docker` and `docker compose`
- Network diagnostic utilities: `lsof`, `ss`, or `netstat`
- Archiving & HTTP utilities: `tar`, `curl`

### Installation

Clone the `kroger_tracker` repository and make the management scripts executable:

```bash
git clone https://github.com/sprillex/kroger_tracker.git
cd kroger_tracker
chmod +x docker_tools/clone_docker.sh
```

## Configuration

The tooling dynamically manages `.env` configuration files for each cloned Docker service. Key injected environment variables include:

| Variable | Description | Example / Default |
| :--- | :--- | :--- |
| `SPRILLEX_DATA_PATH` | Out-of-tree persistent host data path | `/home/james/sprillex/docker/docker_data/<project_name>` |
| `SERVICE_PORT` | Dynamically selected, collision-free host port | `5000` (Range: 1024-65535) |
| `HEALTHCHECK_URL` | Optional endpoint URL to verify container startup | `http://127.0.0.1:${SERVICE_PORT}/health` |

### Reserved Ports Blacklist

`docker_tools/common_ports_do_not_use.csv` maintains a list of reserved ports (e.g. `80`, `443`, `3306`, `5432`, `8080`, `27017`) that `clone_docker.sh` will bypass during automatic port selection.

## Running the Application

### 1. Cloning & Initializing a Docker Repository

Interactive Mode:
```bash
./docker_tools/clone_docker.sh https://github.com/user/docker-project.git
```

Non-Interactive Mode (Automated CI/CD / Scripts):
```bash
./docker_tools/clone_docker.sh https://github.com/user/docker-project.git -y
```

### 2. Managing Cloned Applications (`update.sh`)

Once cloned, navigate to the project directory under `/home/james/sprillex/docker/<project_name>` and use the generated `update.sh`:

Interactive Menu:
```bash
./update.sh
```

CLI Commands:
```bash
# Pull code, create data backup, rebuild images, and restart
./update.sh --update

# Switch to main branch and update
./update.sh --main --update

# View container status and live logs
./update.sh --status
./update.sh --logs

# Restart containers
./update.sh --restart
```

## Testing

Validate script syntax and static integrity using ShellCheck and Bash syntax checks:

```bash
# Verify Bash syntax for clone_docker.sh
bash -n docker_tools/clone_docker.sh

# Run ShellCheck if available
shellcheck docker_tools/clone_docker.sh
```

## API Reference

For complete documentation on command-line interface arguments, exit codes, environment variable schemas, generated lifecycle script interfaces, and health check specifications, please see [API.md](./API.md).
