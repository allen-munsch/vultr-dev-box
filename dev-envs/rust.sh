#!/usr/bin/env bash
set -eo pipefail
echo "==============================="
echo "Rust Dev Environment Setup"
echo "==============================="

#####################################
# Update system
#####################################
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

#####################################
# Install essential tools
#####################################
echo "Installing essential tools..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    wget \
    gh \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    unzip \
    zip \
    htop \
    jq \
    tree \
    ripgrep \
    fd-find \
    bash-completion \
    pkg-config \
    libssl-dev \
    sqlite3 \
    libsqlite3-dev

#####################################
# Install Rust via rustup
#####################################
echo "Installing Rust via rustup..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable

# Load cargo environment
source "$HOME/.cargo/env"

echo "Rust: $(rustc --version)"
echo "Cargo: $(cargo --version)"

#####################################
# Install Rust components
#####################################
echo "Installing Rust components..."
rustup component add clippy rustfmt rust-analyzer

#####################################
# Install useful cargo tools
#####################################
echo "Installing cargo tools..."
cargo install cargo-watch cargo-edit cargo-outdated cargo-audit cargo-tree cargo-expand

#####################################
# Install Docker (optional but handy)
#####################################
echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh

#####################################
# Set up git defaults
#####################################
echo "Configuring git..."
git config --global init.defaultBranch main
git config --global core.editor "code --wait"
git config --global pull.rebase true

#####################################
# Create dev directories
#####################################
echo "Creating dev directories..."
mkdir -p ~/projects
mkdir -p ~/tmp

#####################################
# Set up nice shell experience
#####################################
echo "Setting up shell..."
cat >> ~/.bashrc << 'EOF'

# Cargo environment
. "$HOME/.cargo/env"

# Dev aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias gp='git pull'
alias gd='git diff'
alias ..='cd ..'
alias ...='cd ../..'

# Rust aliases
alias cb='cargo build'
alias cr='cargo run'
alias ct='cargo test'
alias cc='cargo check'
alias cw='cargo watch -x run'
alias cf='cargo fmt'
alias cl='cargo clippy'

# Better history
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups

# Show git branch in prompt
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(parse_git_branch)\[\033[00m\]\$ '

# Go to projects by default
cd ~/projects 2>/dev/null || true
EOF

#####################################
# VS Code workspace file
#####################################
echo "Creating VS Code workspace file..."
cat > ~/projects/workspace.code-workspace << 'EOF'
{
    "folders": [
        {
            "path": "."
        }
    ],
    "settings": {
        "editor.formatOnSave": true,
        "rust-analyzer.checkOnSave.command": "clippy",
        "[rust]": {
            "editor.defaultFormatter": "rust-lang.rust-analyzer",
            "editor.formatOnSave": true
        }
    }
}
EOF

echo ""
echo "==============================="
echo "Setup Complete!"
echo "==============================="
echo ""
echo "Installed:"
echo "  Rust $(rustc --version | cut -d' ' -f2)"
echo "  Cargo $(cargo --version | cut -d' ' -f2)"
echo "  Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
echo "  Git $(git --version | cut -d' ' -f3)"
echo "  sqlite3 $(sqlite3 --version | cut -d' ' -f1)"
echo ""
echo "Rust components:"
echo "  clippy        # linter"
echo "  rustfmt       # formatter"
echo "  rust-analyzer # LSP server"
echo ""
echo "Cargo tools installed:"
echo "  cargo-watch   # auto-recompile on file changes"
echo "  cargo-edit    # add/rm/upgrade dependencies"
echo "  cargo-outdated # check for outdated deps"
echo "  cargo-audit   # security vulnerability scan"
echo "  cargo-tree    # dependency tree"
echo "  cargo-expand  # expand macros"
echo ""
echo "Useful commands:"
echo "  cargo new myproject         # create new binary project"
echo "  cargo new --lib mylib       # create new library"
echo "  cargo init                  # init in existing dir"
echo "  cargo add serde             # add dependency"
echo "  cargo build --release       # optimized build"
echo "  cargo watch -x run          # auto-rebuild on changes"
echo "  cargo clippy                # run linter"
echo "  cargo fmt                   # format code"
echo ""
echo "Next steps:"
echo "  1. Install 'rust-analyzer' extension in VS Code"
echo "  2. Press Cmd/Ctrl+Shift+P -> 'Remote-SSH: Connect to Host'"
echo "  3. Enter: root@<your-ip> (or use the host alias)"
echo "  4. Open ~/projects and start coding!"
echo ""
