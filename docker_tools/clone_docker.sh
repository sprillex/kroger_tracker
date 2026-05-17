#!/usr/bin/env bash
set -e
set -o pipefail

# Sprillex Docker Project Clone Tool
# This script clones a Docker repository, sets up a persistent data directory,
# and generates a Sprillex-compliant update.sh script for lifecycle management.

TARGET_BASE_DIR="/home/james/sprillex/docker"
DATA_BASE_DIR="$TARGET_BASE_DIR/docker_data"
COMMON_PORTS_FILE="$(dirname "$0")/common_ports_do_not_use.csv"
NON_INTERACTIVE=false
GITHUB_URL=""

show_help() {
    echo "Usage: $0 [GITHUB_URL] [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -y, --yes       Run in non-interactive mode (requires GITHUB_URL)"
    echo "  -h, --help      Display this help message"
}

# --- Helper Functions ---
log_info() { echo -e "INFO: $1"; }
log_warn() { echo -e "WARN: $1"; }
log_error() { echo -e "ERROR: $1"; }

is_port_in_use() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        lsof -i ":$port" -sTCP:LISTEN >/dev/null 2>&1
        return $?
    elif command -v ss >/dev/null 2>&1; then
        ss -tln | grep -q ":$port "
        return $?
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tln | grep -q ":$port "
        return $?
    else
        log_warn "Could not check if port $port is in use (missing lsof/ss/netstat)."
        return 1 # Assume free if we can't check
    fi
}

is_port_forbidden() {
    local port=$1
    if [ -f "$COMMON_PORTS_FILE" ]; then
        if grep -q "^$port," "$COMMON_PORTS_FILE"; then
            return 0 # True, it is forbidden
        fi
    fi
    return 1 # False
}

get_input() {
    local prompt_text="$1"
    local var_name="$2"
    local default_val="$3"
    local allow_empty="$4"
    local input_val=""

    local env_val="${!var_name}"

    if [[ "$NON_INTERACTIVE" == true ]]; then
        if [ -n "$env_val" ]; then
            declare -g "$var_name=$env_val"
        elif [ -n "$default_val" ]; then
            declare -g "$var_name=$default_val"
        elif [ "$allow_empty" == "true" ]; then
            declare -g "$var_name="
        else
            log_error "Non-interactive mode requires \$${var_name} or a default value."
            exit 1
        fi
        return 0
    fi

    if [ -n "$env_val" ]; then
        default_val="$env_val"
    fi

    while true; do
        if [ -n "$default_val" ]; then
            read -p "$prompt_text [$default_val]: " input_val </dev/tty
        else
            read -p "$prompt_text: " input_val </dev/tty
        fi

        input_val="${input_val:-$default_val}"

        if [ -z "$input_val" ] && [ "$allow_empty" != "true" ]; then
            log_error "This value cannot be empty."
        else
            declare -g "$var_name=$input_val"
            break
        fi
    done
}

select_port() {
    local var_name="$1"
    local default_port="$2"
    local selected_port=""

    if [[ "$NON_INTERACTIVE" == true ]]; then
        selected_port="${!var_name:-$default_port}"

        # Ensure we have a valid numeric baseline before doing arithmetic
        if [[ ! "$selected_port" =~ ^[0-9]+$ ]]; then
            log_warn "Non-interactive mode: Default port '$selected_port' is missing or not a number. Defaulting to 5000."
            selected_port=5000
        fi

        while true; do
            if [ "$selected_port" -lt 1024 ] || is_port_forbidden "$selected_port" || is_port_in_use "$selected_port"; then
                log_warn "Non-interactive mode: Port $selected_port is invalid, forbidden, or in use. Trying next port..."
                selected_port=$((selected_port + 1))
                if [ "$selected_port" -gt 65535 ]; then
                    log_error "Non-interactive mode: Could not find an available port."
                    exit 1
                fi
            else
                log_info "Non-interactive mode: Port $selected_port is available."
                declare -g "$var_name=$selected_port"
                break
            fi
        done
        return 0
    fi

    while true; do
        get_input "Enter Service Port (1024-65535)" "$var_name" "$default_port"
        selected_port="${!var_name}"

        # 1. Numeric check
        if [[ ! "$selected_port" =~ ^[0-9]+$ ]]; then
            log_error "Port must be a number."
            continue
        fi

        # 2. Range check
        if [ "$selected_port" -lt 1024 ] || [ "$selected_port" -gt 65535 ]; then
            log_error "Port must be between 1024 and 65535."
            continue
        fi

        # 3. Forbidden list check
        if is_port_forbidden "$selected_port"; then
             log_error "Port $selected_port is in the forbidden list ($COMMON_PORTS_FILE)."
             continue
        fi

        # 4. In use check
        if is_port_in_use "$selected_port"; then
             log_error "Port $selected_port is currently in use by another process."
             continue
        fi

        log_info "Port $selected_port is available."
        break
    done
}


# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            NON_INTERACTIVE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown flag: $1"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$GITHUB_URL" ]; then
                GITHUB_URL="$1"
            else
                echo "Warning: Extra positional argument ignored: $1"
            fi
            shift
            ;;
    esac
done

# Prompt for URL if not provided
if [ -z "$GITHUB_URL" ]; then
    if [ "$NON_INTERACTIVE" = true ]; then
        echo "Error: GITHUB_URL is required in non-interactive mode."
        exit 1
    fi
    echo "Sprillex Docker Clone Utility"
    echo "Note: If this is a private repo, ensure your Git credentials (e.g., PAT) are cached."
    read -p "Enter the GitHub repository URL (e.g., https://github.com/user/repo.git): " GITHUB_URL
fi

# Validate URL
if [[ ! "$GITHUB_URL" =~ \.git$ ]]; then
    echo "Error: The URL should end with '.git'."
    exit 1
fi

# Extract project name from URL
# e.g., https://github.com/user/my-project.git -> my-project
PROJECT_NAME=$(basename "$GITHUB_URL" .git)
PROJECT_DIR="$TARGET_BASE_DIR/$PROJECT_NAME"
PROJECT_DATA_DIR="$DATA_BASE_DIR/$PROJECT_NAME"

echo "------------------------------------------"
echo "Project Name: $PROJECT_NAME"
echo "Target Dir:   $PROJECT_DIR"
echo "Data Dir:     $PROJECT_DATA_DIR"
echo "------------------------------------------"

# Create base directories if they don't exist
mkdir -p "$TARGET_BASE_DIR"
mkdir -p "$DATA_BASE_DIR"

if [ -d "$PROJECT_DIR" ]; then
    echo "Error: Directory $PROJECT_DIR already exists."
    exit 1
fi

# Clone the repository
echo "Cloning repository..."
git clone "$GITHUB_URL" "$PROJECT_DIR"

cd "$PROJECT_DIR"

# Create the persistent data directory
echo "Setting up persistent data directory..."
mkdir -p "$PROJECT_DATA_DIR"

# Handle .env configuration
ENV_FILE="$PROJECT_DIR/.env"
if [ -f "$PROJECT_DIR/.env.example" ] && [ ! -f "$ENV_FILE" ]; then
    echo "Copying .env.example to .env..."
    cp "$PROJECT_DIR/.env.example" "$ENV_FILE"
else
    # Create empty .env if neither exists
    touch "$ENV_FILE"
fi

# Inject SPRILLEX_DATA_PATH
if grep -q "^SPRILLEX_DATA_PATH=" "$ENV_FILE"; then
    # Update existing value
    sed -i "s|^SPRILLEX_DATA_PATH=.*|SPRILLEX_DATA_PATH=$PROJECT_DATA_DIR|" "$ENV_FILE"
else
    # Append value
    echo "" >> "$ENV_FILE"
    echo "# Sprillex standard persistent data path" >> "$ENV_FILE"
    echo "SPRILLEX_DATA_PATH=$PROJECT_DATA_DIR" >> "$ENV_FILE"
fi
echo "Injected SPRILLEX_DATA_PATH=$PROJECT_DATA_DIR into .env"

# Handle Port Selection
REQUIRE_PORT=false
if [[ "$NON_INTERACTIVE" == false ]]; then
    read -p "Does this Docker project require a server port? (y/n): " </dev/tty
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        REQUIRE_PORT=true
    fi
else
    # In non-interactive mode, we always try to select a port just in case it's needed
    REQUIRE_PORT=true
fi

if [[ "$REQUIRE_PORT" == true ]]; then
    echo "Selecting server port..."
    select_port "SERVICE_PORT" 5000

    if grep -q "^SERVICE_PORT=" "$ENV_FILE"; then
        sed -i "s|^SERVICE_PORT=.*|SERVICE_PORT=$SERVICE_PORT|" "$ENV_FILE"
    else
        echo "" >> "$ENV_FILE"
        echo "# Selected Server Port" >> "$ENV_FILE"
        echo "SERVICE_PORT=$SERVICE_PORT" >> "$ENV_FILE"
    fi
    echo "Injected SERVICE_PORT=$SERVICE_PORT into .env"
fi

echo "HEALTH CHECK URL: Optional URL to curl after start to verify connectivity."
echo "Example: http://127.0.0.1:\${SERVICE_PORT:-5000}/health (Leave empty to skip)"
get_input "Enter Health Check URL" "HEALTHCHECK_URL" "" "true"

if [ -n "$HEALTHCHECK_URL" ]; then
    if grep -q "^HEALTHCHECK_URL=" "$ENV_FILE"; then
        sed -i "s|^HEALTHCHECK_URL=.*|HEALTHCHECK_URL=$HEALTHCHECK_URL|" "$ENV_FILE"
    else
        echo "" >> "$ENV_FILE"
        echo "# Health Check Endpoint" >> "$ENV_FILE"
        echo "HEALTHCHECK_URL=$HEALTHCHECK_URL" >> "$ENV_FILE"
    fi
    echo "Injected HEALTHCHECK_URL=$HEALTHCHECK_URL into .env"
fi

# Generate update.sh
UPDATE_SCRIPT="$PROJECT_DIR/update.sh"
echo "Generating Sprillex-compliant update.sh..."

cat << 'EOF' > "$UPDATE_SCRIPT"
#!/usr/bin/env bash
set -e
set -o pipefail

# Sprillex Docker Project Update Script
# Generated by clone_docker.sh

# ANSI Colors
COLORS_RED='\033[0;31m'
COLORS_GREEN='\033[0;32m'
COLORS_YELLOW='\033[1;33m'
COLORS_BLUE='\033[0;34m'
COLORS_NC='\033[0m' # No Color

# --- Helper Functions ---
log_info() { echo -e "${COLORS_GREEN}[INFO]${COLORS_NC} $1"; }
log_warn() { echo -e "${COLORS_YELLOW}[WARN]${COLORS_NC} $1"; }
log_error() { echo -e "${COLORS_RED}[ERROR]${COLORS_NC} $1"; }
log_header() { echo -e "${COLORS_BLUE}$1${COLORS_NC}"; }

is_port_in_use() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        lsof -i ":$port" -sTCP:LISTEN >/dev/null 2>&1
        return $?
    elif command -v ss >/dev/null 2>&1; then
        ss -tln | grep -q ":$port "
        return $?
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tln | grep -q ":$port "
        return $?
    else
        log_warn "Could not check if port $port is in use (missing lsof/ss/netstat)."
        return 1 # Assume free if we can't check
    fi
}

verify_port_before_start() {
    if [ -f ".env" ]; then
        local saved_port=$(grep "^SERVICE_PORT=" ".env" | cut -d'=' -f2- || true)
        if [ -n "$saved_port" ]; then
            log_info "Verifying port $saved_port is still available before startup..."
            if is_port_in_use "$saved_port"; then
                log_error "CRITICAL: Port $saved_port was taken by another process."
                log_error "Aborting docker compose up to prevent a crash loop."
                exit 1
            fi
        fi
    fi
}

wait_for_healthcheck() {
    local url="$1"
    local max_retries=30 # 30 seconds
    local count=0

    if [ -z "$url" ]; then return 0; fi

    log_info "Waiting for service to initialize (up to ${max_retries}s)..."

    while [ "$count" -lt "$max_retries" ]; do
        if curl -f -s -o /dev/null "$url"; then
            echo "" # Newline
            log_info "SUCCESS: Service is responding at $url"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        echo -ne "."
    done
    echo "" # Newline

    log_warn "WARNING: Service failed to respond at $url after ${max_retries} seconds"
    log_warn "Check logs with: docker compose logs"
    return 1
}

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME=$(basename "$PROJECT_DIR")
DATA_DIR="/home/james/sprillex/docker/docker_data/$PROJECT_NAME"

cd "$PROJECT_DIR"

DO_UPDATE=false
DO_MAIN=false
DO_NEWEST=false
DO_LOGS=false
DO_STATUS=false
DO_RESTART=false
NON_INTERACTIVE=false
HAS_ARGS=false

show_help() {
    echo "Usage: ./update.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --update    Pull git, backup data, rebuild, and restart containers"
    echo "  -m, --main      Switch to main/master branch before updating"
    echo "  -n, --newest    Switch to the newest remote branch before updating"
    echo "  -s, --status    Show docker compose status"
    echo "  -l, --logs      Show docker compose logs"
    echo "  -r, --restart   Restart docker containers"
    echo "  -c, --settings  Manage settings (Edit .env)"
    echo "  -y, --yes       Run non-interactively (bypass prompts)"
    echo "  -h, --help      Display this help message"
}

while [[ $# -gt 0 ]]; do
    HAS_ARGS=true
    case $1 in
        -u|--update) DO_UPDATE=true; shift ;;
        -m|--main) DO_MAIN=true; shift ;;
        -n|--newest) DO_NEWEST=true; shift ;;
        -s|--status) DO_STATUS=true; shift ;;
        -l|--logs) DO_LOGS=true; shift ;;
        -r|--restart) DO_RESTART=true; shift ;;
        -c|--settings)
            log_info "To edit settings, modify the .env file:"
            echo "nano $PROJECT_DIR/.env"
            exit 0
            ;;
        -y|--yes) NON_INTERACTIVE=true; shift ;;
        -h|--help) show_help; exit 0 ;;
        -*) echo "Unknown flag: $1"; show_help; exit 1 ;;
        *) echo "Ignored argument: $1"; shift ;;
    esac
done

# Determine if we should perform an interactive menu
if [ "$HAS_ARGS" = false ]; then
    if [ "$NON_INTERACTIVE" = true ]; then
        log_info "No action flags provided in non-interactive mode. Exiting."
        exit 0
    fi
    log_header "--- Sprillex: $PROJECT_NAME Update Menu ---"
    PS3="Select an option: "
    options=("Status" "Logs" "Restart" "Update" "Quit")
    select opt in "${options[@]}"; do
        case $opt in
            "Status") DO_STATUS=true; break ;;
            "Logs") DO_LOGS=true; break ;;
            "Restart") DO_RESTART=true; break ;;
            "Update") DO_UPDATE=true; break ;;
            "Quit") exit 0 ;;
            *) log_warn "Invalid option." ;;
        esac
    done
fi

if [ "$DO_STATUS" = true ]; then
    log_header "Container Status:"
    docker compose ps
fi

if [ "$DO_LOGS" = true ]; then
    log_header "Container Logs:"
    docker compose logs --tail=100 -f
fi

if [ "$DO_RESTART" = true ] && [ "$DO_UPDATE" = false ]; then
    log_info "Restarting containers..."
    docker compose down
    verify_port_before_start
    docker compose up -d

    if [ -f ".env" ]; then
        HEALTHCHECK_URL=$(grep "^HEALTHCHECK_URL=" ".env" | cut -d'=' -f2- || true)
        if [ -n "$HEALTHCHECK_URL" ]; then
            wait_for_healthcheck "$HEALTHCHECK_URL"
        fi
    fi
fi

if [ "$DO_MAIN" = true ]; then
    log_info "Switching to main branch..."
    git fetch
    git checkout $(git rev-parse --abbrev-ref origin/HEAD | sed 's|origin/||')
fi

if [ "$DO_NEWEST" = true ]; then
    log_info "Switching to newest branch..."
    git fetch
    NEWEST_BRANCH=$(git branch -r --sort=-committerdate | grep -v HEAD | head -n 1 | sed 's|origin/||' | xargs)
    if [ -n "$NEWEST_BRANCH" ]; then
        git checkout "$NEWEST_BRANCH"
    else
        log_warn "Could not determine newest branch."
    fi
fi

if [ "$DO_UPDATE" = true ]; then
    log_header "Starting update process for $PROJECT_NAME..."

    log_info "1. Pulling latest code..."
    CHECKSUM_BEFORE=$(sha256sum "$0" | awk '{print $1}')
    git pull
    CHECKSUM_AFTER=$(sha256sum "$0" | awk '{print $1}')

    if [ "$CHECKSUM_BEFORE" != "$CHECKSUM_AFTER" ]; then
        log_warn "UPDATE SCRIPT CHANGED - RESTARTING PROCESS..."
        exec "$0" "$@"
    fi

    if [ -d "$DATA_DIR" ]; then
        log_info "2. Backing up persistent data..."
        BACKUP_FILE="${DATA_DIR}_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$BACKUP_FILE" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"
        log_info "   Backup saved to: $BACKUP_FILE"
    else
        log_warn "2. No data directory found at $DATA_DIR, skipping backup."
    fi

    log_info "3. Tearing down containers..."
    docker compose down

    log_info "4. Rebuilding and pulling images..."
    docker compose build --pull || true
    docker compose pull

    log_info "5. Starting containers..."
    verify_port_before_start
    docker compose up -d

    if [ -f ".env" ]; then
        HEALTHCHECK_URL=$(grep "^HEALTHCHECK_URL=" ".env" | cut -d'=' -f2- || true)
        if [ -n "$HEALTHCHECK_URL" ]; then
            wait_for_healthcheck "$HEALTHCHECK_URL"
        fi
    fi

    log_info "Update complete!"
fi
EOF

chmod +x "$UPDATE_SCRIPT"
echo "Generated $UPDATE_SCRIPT"

echo "------------------------------------------"
echo "Setup complete for $PROJECT_NAME."
echo "------------------------------------------"

if [ "$NON_INTERACTIVE" = false ]; then
    read -p "Would you like to build and start the containers now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Starting containers..."
        docker compose up -d --build
    fi
else
    echo "Starting containers automatically (non-interactive)..."
    docker compose up -d --build
fi

exit 0
