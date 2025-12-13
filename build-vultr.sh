#!/usr/bin/env bash
set -eo pipefail
echo "==============================="
echo " Vultr CLI Build Script"
echo "==============================="
#####################################
# Settings
#####################################
REPO_DIR="$HOME/projects/repos/vultr-cli"
GO_VERSION="1.24.0"
INSTALL_PATH="/usr/local/bin/vultr-cli"
#####################################
# Clean up gvm environment pollution
#####################################
unset GOROOT
unset GOPATH
unset GVM_ROOT
unset GVM_OVERLAY_PREFIX
# Remove any gvm paths from PATH
PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "\.gvm" | tr '\n' ':' | sed 's/:$//')
#####################################
# Install Go directly
#####################################
export GOROOT="/usr/local/go"
export PATH="$GOROOT/bin:$PATH"

if [[ -x "$GOROOT/bin/go" ]] && "$GOROOT/bin/go" version | grep -q "go$GO_VERSION"; then
    echo " Go $GO_VERSION already installed"
else
    echo " Installing Go $GO_VERSION..."
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64) GO_ARCH="amd64" ;;
        arm64|aarch64) GO_ARCH="arm64" ;;
        *) echo " Unsupported arch: $ARCH"; exit 1 ;;
    esac
    
    GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    curl -fsSL "https://go.dev/dl/${GO_TAR}" -o "/tmp/${GO_TAR}"
    sudo rm -rf "$GOROOT"
    sudo tar -C /usr/local -xzf "/tmp/${GO_TAR}"
    rm "/tmp/${GO_TAR}"
fi

echo " Clearing Go caches..."
"$GOROOT/bin/go" clean -cache -modcache -testcache

echo " GOROOT: $GOROOT"
echo " Go version: $("$GOROOT/bin/go" version)"
#####################################
# Detect OS and ARCH
#####################################
UNAME_OS="$(uname -s)"
case "$UNAME_OS" in
    Darwin) OS="darwin" ;;
    Linux)  OS="linux" ;;
    CYGWIN*|MINGW*|MSYS*) OS="windows" ;;
    *) echo " Unsupported OS: $UNAME_OS"; exit 1 ;;
esac
UNAME_ARCH="$(uname -m)"
case "$UNAME_ARCH" in
    x86_64|amd64) ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
    i386|i686) ARCH="386" ;;
    *) echo " Unsupported ARCH: $UNAME_ARCH"; exit 1 ;;
esac
echo " Detected OS: $OS"
echo " Detected ARCH: $ARCH"
#####################################
# Clone repo fresh
#####################################
if [[ -d "$REPO_DIR" ]]; then
    echo "  Removing existing repo at $REPO_DIR..."
    rm -rf "$REPO_DIR"
fi
echo " Cloning vultr-cli..."
mkdir -p "$(dirname "$REPO_DIR")"
git clone --depth 1 https://github.com/vultr/vultr-cli.git "$REPO_DIR"
echo " Changing to: $REPO_DIR"
builtin cd "$REPO_DIR"
echo " Working in: $(pwd)"
#####################################
# Build binary
#####################################
TARGET="builds/vultr-cli_${OS}_${ARCH}"
if [[ "$OS" == "windows" ]]; then
    TARGET="${TARGET}.exe"
    INSTALL_PATH="${INSTALL_PATH}.exe"
fi
echo " Building target: $TARGET"
make "$TARGET"
#####################################
# Install binary
#####################################
echo " Installing to: $INSTALL_PATH"
sudo install -m 755 "$TARGET" "$INSTALL_PATH"
#####################################
# Verify installation
#####################################
echo " Verifying installation..."
if command -v vultr-cli >/dev/null 2>&1; then
    echo " vultr-cli installed successfully!"
    echo " Location: $(command -v vultr-cli)"
    vultr-cli version
else
    echo " Installation failed. Check your PATH."
fi
echo " Done! You can now run: vultr-cli"