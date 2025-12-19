#!/bin/bash
#
# Forgejo Actions Runner Setup Script
# Sets up forgejo-runner with Podman (open source Docker alternative)
#

set -euo pipefail

# Configuration
FORGEJO_URL="${FORGEJO_URL:-http://localhost:3000}"
FORGEJO_CONFIG="/etc/forgejo/app.ini"
RUNNER_USER="runner"
RUNNER_HOME="/home/${RUNNER_USER}"
RUNNER_VERSION="${RUNNER_VERSION:-}"  # Empty = latest

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Detect architecture
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "arm-6" ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Get latest runner version
get_latest_version() {
    curl -s 'https://data.forgejo.org/api/v1/repos/forgejo/runner/releases/latest' | \
        grep -oP '"name":\s*"v\K[^"]+' | head -1
}

# Install Podman (open source Docker alternative)
install_podman() {
    log_step "Checking Podman installation..."
    
    if command -v podman &>/dev/null; then
        log_info "Podman already installed: $(podman --version)"
    else
        log_info "Installing Podman..."
        
        apt-get update -qq
        apt-get install -y -qq podman podman-docker acl
        
        log_info "Podman installed: $(podman --version)"
    fi
    
    # Enable podman socket for Docker API compatibility
    log_info "Enabling Podman socket..."
    systemctl enable --now podman.socket
    
    # Wait for socket to be created
    sleep 2
    
    # Verify socket exists and set permissions
    local socket_path="/run/podman/podman.sock"
    if [[ -S "$socket_path" ]]; then
        log_info "Podman socket available at $socket_path"
        
        # Give runner user access to the socket using ACL
        setfacl -m u:${RUNNER_USER}:rw "$socket_path"
        log_info "Granted ${RUNNER_USER} access to Podman socket"
    else
        log_error "Podman socket not found at $socket_path"
        log_error "Check: systemctl status podman.socket"
        return 1
    fi
    
    # Create a systemd service to set ACL after socket starts
    cat > /etc/systemd/system/podman-socket-acl.service << EOF
[Unit]
Description=Set ACL on Podman socket for runner user
After=podman.socket
Requires=podman.socket

[Service]
Type=oneshot
ExecStart=/usr/bin/setfacl -m u:${RUNNER_USER}:rw /run/podman/podman.sock
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now podman-socket-acl.service
    
    # Verify runner can access podman
    if sudo -u "${RUNNER_USER}" podman info &>/dev/null; then
        log_info "Verified: ${RUNNER_USER} can access Podman"
    else
        log_warn "Runner may not have Podman access - will retry on start"
    fi
}

# Create runner user
create_runner_user() {
    log_step "Setting up runner user..."
    
    if id "${RUNNER_USER}" &>/dev/null; then
        log_warn "User '${RUNNER_USER}' already exists"
    else
        useradd --create-home --shell /bin/bash "${RUNNER_USER}"
        log_info "User '${RUNNER_USER}' created"
    fi
    
    # Enable lingering so user services persist
    loginctl enable-linger "${RUNNER_USER}" 2>/dev/null || true
    
    log_info "User '${RUNNER_USER}' configured for Podman"
}

# Download and install forgejo-runner
install_runner() {
    log_step "Installing forgejo-runner..."
    
    local arch
    arch=$(detect_arch)
    
    if [[ -z "$RUNNER_VERSION" ]]; then
        log_info "Fetching latest runner version..."
        RUNNER_VERSION=$(get_latest_version)
    fi
    
    log_info "Installing forgejo-runner v${RUNNER_VERSION} for ${arch}"
    
    local url="https://code.forgejo.org/forgejo/runner/releases/download/v${RUNNER_VERSION}/forgejo-runner-${RUNNER_VERSION}-linux-${arch}"
    
    wget -q --show-progress -O /usr/local/bin/forgejo-runner "$url"
    chmod +x /usr/local/bin/forgejo-runner
    
    log_info "Installed: $(forgejo-runner --version)"
}

# Enable Actions in Forgejo
enable_forgejo_actions() {
    log_step "Enabling Forgejo Actions..."
    
    if [[ ! -f "$FORGEJO_CONFIG" ]]; then
        log_warn "Forgejo config not found at $FORGEJO_CONFIG - skipping"
        log_warn "You'll need to manually add Actions settings to app.ini"
        return 0
    fi
    
    # Check if actions section exists
    if grep -q "^\[actions\]" "$FORGEJO_CONFIG"; then
        log_info "Actions section already exists in app.ini"
        # Ensure ENABLED = true
        if grep -q "^ENABLED\s*=\s*false" "$FORGEJO_CONFIG"; then
            sed -i 's/^ENABLED\s*=\s*false/ENABLED = true/' "$FORGEJO_CONFIG"
            log_info "Enabled Actions in existing config"
        fi
    else
        # Add actions section
        cat >> "$FORGEJO_CONFIG" << 'EOF'

[actions]
ENABLED = true
DEFAULT_ACTIONS_URL = https://data.forgejo.org
EOF
        log_info "Added Actions section to app.ini"
    fi
    
    # Restart Forgejo to apply changes
    if systemctl is-active --quiet forgejo; then
        log_info "Restarting Forgejo to apply changes..."
        systemctl restart forgejo
        sleep 3
    fi
}

# Create runner configuration
create_runner_config() {
    log_step "Creating runner configuration..."
    
    local config_dir="${RUNNER_HOME}"
    local config_file="${config_dir}/config.yml"
    
    cat > "$config_file" << 'EOF'
# Forgejo Runner Configuration (using Podman)

log:
  level: info
  job_level: info

runner:
  file: .runner
  capacity: 1
  timeout: 3h
  shutdown_timeout: 3h
  insecure: false
  fetch_timeout: 5s
  fetch_interval: 2s
  labels:
    - "docker:docker://node:20-bookworm"
    - "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-22.04"
    - "ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04"

cache:
  enabled: true
  dir: ""
  host: ""
  port: 0

container:
  network: ""
  privileged: false
  options:
  workdir_parent:
  valid_volumes: []
  # Use Podman socket (Docker-compatible)
  docker_host: "unix:///run/podman/podman.sock"
  force_pull: false
EOF

    chown "${RUNNER_USER}:${RUNNER_USER}" "$config_file"
    chmod 644 "$config_file"
    
    log_info "Configuration created at $config_file"
}

# Create systemd service
create_systemd_service() {
    log_step "Creating systemd service..."
    
    cat > /etc/systemd/system/forgejo-runner.service << EOF
[Unit]
Description=Forgejo Actions Runner
Documentation=https://forgejo.org/docs/latest/admin/actions/
After=podman.socket podman-socket-acl.service
Requires=podman.socket
Wants=podman-socket-acl.service

[Service]
Type=simple
User=${RUNNER_USER}
Group=${RUNNER_USER}
WorkingDirectory=${RUNNER_HOME}
Environment=DOCKER_HOST=unix:///run/podman/podman.sock
ExecStart=/usr/local/bin/forgejo-runner daemon --config ${RUNNER_HOME}/config.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_info "Systemd service created"
}

# Interactive registration
register_runner() {
    log_step "Runner Registration"
    echo
    echo "To register the runner, you need a registration token from Forgejo."
    echo
    echo "Get it from one of these locations in your Forgejo instance:"
    echo "  - Site Admin:    /admin/actions/runners"
    echo "  - Organization:  /org/{name}/settings/actions/runners"  
    echo "  - Repository:    /{owner}/{repo}/settings/actions/runners"
    echo
    echo "Click 'Create new runner' to get the token."
    echo
    
    read -rp "Enter the Forgejo instance URL [${FORGEJO_URL}]: " input_url
    FORGEJO_URL="${input_url:-$FORGEJO_URL}"
    
    read -rp "Enter the registration token: " token
    if [[ -z "$token" ]]; then
        log_error "Token cannot be empty"
        return 1
    fi
    
    read -rp "Enter runner name [$(hostname)-runner]: " runner_name
    runner_name="${runner_name:-$(hostname)-runner}"
    
    echo
    echo "Default labels provide these environments:"
    echo "  - docker              -> node:20-bookworm"
    echo "  - ubuntu-latest       -> ghcr.io/catthehacker/ubuntu:act-22.04"
    echo "  - ubuntu-22.04        -> ghcr.io/catthehacker/ubuntu:act-22.04"
    echo
    read -rp "Use default labels? [Y/n]: " use_defaults
    
    local labels=""
    if [[ ! "$use_defaults" =~ ^[Nn] ]]; then
        labels="docker:docker://node:20-bookworm,ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-22.04,ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04"
    else
        echo "Enter custom labels (format: name:docker://image, comma-separated):"
        read -rp "Labels: " labels
    fi
    
    echo
    log_info "Registering runner..."
    
    # Run registration as runner user
    sudo -u "${RUNNER_USER}" bash -c "
        cd ${RUNNER_HOME}
        forgejo-runner register \
            --instance '${FORGEJO_URL}' \
            --token '${token}' \
            --name '${runner_name}' \
            --labels '${labels}' \
            --no-interactive
    "
    
    if [[ $? -eq 0 ]]; then
        log_info "Runner registered successfully!"
        return 0
    else
        log_error "Registration failed"
        return 1
    fi
}

# Start the runner service
start_runner() {
    log_step "Starting runner service..."
    
    # Ensure Podman socket ACL is set
    if [[ -S "/run/podman/podman.sock" ]]; then
        setfacl -m u:${RUNNER_USER}:rw /run/podman/podman.sock 2>/dev/null || true
    fi
    
    systemctl enable forgejo-runner.service
    systemctl start forgejo-runner.service
    
    sleep 2
    
    if systemctl is-active --quiet forgejo-runner; then
        log_info "Runner service started successfully"
    else
        log_error "Runner service failed to start"
        log_error "Check logs: journalctl -u forgejo-runner -n 50"
        return 1
    fi
}

# Print summary
print_summary() {
    echo
    echo "=============================================="
    echo -e "${GREEN}Forgejo Actions Runner Setup Complete!${NC}"
    echo "=============================================="
    echo
    echo "Container Runtime: Podman (Docker-compatible)"
    echo "Runner User:       ${RUNNER_USER}"
    echo "Runner Home:       ${RUNNER_HOME}"
    echo "Config File:       ${RUNNER_HOME}/config.yml"
    echo "Forgejo URL:       ${FORGEJO_URL}"
    echo
    echo "Available labels for workflows (runs-on):"
    echo "  - docker"
    echo "  - ubuntu-latest"
    echo "  - ubuntu-22.04"
    echo
    echo "Useful commands:"
    echo "  - Check status:  systemctl status forgejo-runner"
    echo "  - View logs:     journalctl -u forgejo-runner -f"
    echo "  - Restart:       systemctl restart forgejo-runner"
    echo "  - Podman info:   podman info"
    echo "  - List images:   podman images"
    echo
    echo "Note: 'docker' command also works (symlinked to podman)"
    echo
    echo "Example workflow (.forgejo/workflows/test.yml):"
    echo "-------------------------------------------"
    cat << 'EOF'
name: Test
on: [push]
jobs:
  test:
    runs-on: docker
    steps:
      - uses: actions/checkout@v4
      - run: echo "Hello from Forgejo Actions!"
EOF
    echo "-------------------------------------------"
    echo
}

# Show help
show_help() {
    echo "Forgejo Actions Runner Setup Script"
    echo
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "  install     Full installation (default)"
    echo "  register    Register runner only (if already installed)"
    echo "  enable      Enable Actions in Forgejo only"
    echo "  help        Show this help"
    echo
    echo "Environment variables:"
    echo "  FORGEJO_URL      Forgejo instance URL (default: http://localhost:3000)"
    echo "  RUNNER_VERSION   Specific runner version (default: latest)"
    echo
}

# Main installation
main_install() {
    echo
    echo "=============================================="
    echo "  Forgejo Actions Runner Setup"
    echo "=============================================="
    echo
    
    check_root
    create_runner_user
    install_podman
    install_runner
    enable_forgejo_actions
    create_runner_config
    create_systemd_service
    
    echo
    read -rp "Register runner now? [Y/n]: " do_register
    if [[ ! "$do_register" =~ ^[Nn] ]]; then
        register_runner
        start_runner
    else
        echo
        log_warn "Skipping registration. Run '$0 register' later to register."
        log_warn "After registration, start with: systemctl start forgejo-runner"
    fi
    
    print_summary
}

# Entry point
case "${1:-install}" in
    install)
        main_install
        ;;
    register)
        check_root
        register_runner
        start_runner
        ;;
    enable)
        check_root
        enable_forgejo_actions
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac