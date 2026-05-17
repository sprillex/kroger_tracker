# AI Coder Instruction Manual: Docker Tools

## 1. System Context & Purpose
This document provides AI agents with the necessary context for managing, generating, and structuring Docker projects within the ecosystem. The tools ensure automated repository cloning, strict data isolation, intelligent network port allocation, and automated lifecycle management script generation.

### Key Components:
- `docker_tools/clone_docker.sh`: A utility that automates the cloning of Docker repositories, allocates persistent storage, resolves port bindings, and outputs an `update.sh` script compliant with the Sprillex ecosystem.
- `docker_tools/common_ports_do_not_use.csv`: A blacklist of ports that the intelligent port selector must ignore to avoid ecosystem conflicts.

## 2. Strict Constraints & Operational Rules
When modifying or instructing on Docker projects within this ecosystem, AI must adhere strictly to the following constraints:
- **READ-ONLY Mode Acknowledgment:** You must not alter the core logic of `clone_docker.sh` without explicit user instruction.
- **Port Allocation:** The tool dynamically allocates ports. It prevents collisions by avoiding the `common_ports_do_not_use.csv` list and scanning the host for availability.
- **Data Persistence Strategy:** Docker persistent data must not reside arbitrarily within the repository folder. The tool isolates data into a centralized `docker_data` folder (e.g., `/home/user/sprillex/docker/docker_data`).

## 3. Integration & Setup Steps

### 3.1. Project Initialization
To clone and automatically configure a new Docker repository:
```bash
./docker_tools/clone_docker.sh https://github.com/user/docker-project.git
```
*Note: The script supports an interactive mode (asking about port requirements) or a non-interactive mode (using `-y`).*

### 3.2. Sprillex Docker Compose Standard
When generating or modifying `docker-compose.yml` files for the ecosystem, you must strictly integrate the environment variables injected by `clone_docker.sh` into the project's `.env` file.

**Volume Binding (Mandatory for Persistence):**
You must map volumes relative to the auto-injected `SPRILLEX_DATA_PATH` environment variable.
```yaml
volumes:
  - ${SPRILLEX_DATA_PATH}/db:/var/lib/mysql
  - ${SPRILLEX_DATA_PATH}/config:/app/config
```

**Port Binding:**
You must bind the exposed ports relative to the auto-injected `SERVICE_PORT` environment variable.
```yaml
ports:
  - "${SERVICE_PORT}:8080"
```

### 3.3. Update Manager Compatibility
The `clone_docker.sh` tool automatically generates an `update.sh` script inside the cloned repository.
This script is explicitly designed to comply with `universal_update_manager.sh`. It handles mass updates seamlessly by accepting ecosystem-standard flags (`-u`, `-m`, `-n`, `-c`, `-s`, `-l`, `-r`, `-h`).

## 4. State Modifications & Data Handling
- **Dotenv (.env) Injection:** The tool dynamically writes the selected `SERVICE_PORT` and computed `SPRILLEX_DATA_PATH` into the `.env` file. AI should read from `.env` and configure dependent systems (like Nginx reverse proxies) using these variables.
- **File Hierarchy:** The host categorizes Docker projects strictly under the `docker` folder umbrella (e.g., `/home/user/sprillex/docker`). Data directories are maintained in parallel out-of-tree from the cloned source code to prevent accidental deletion during hard Git resets or updates.
