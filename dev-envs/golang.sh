#!/usr/bin/env bash
set -eo pipefail
echo "==============================="
echo "Go Dev Environment Setup"
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
    sqlite3 \
    libsqlite3-dev

#####################################
# Install Go
#####################################
GO_VERSION="1.23.4"
echo "Installing Go ${GO_VERSION}..."

ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) GO_ARCH="amd64" ;;
    arm64|aarch64) GO_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
curl -fsSL "https://go.dev/dl/${GO_TAR}" -o "/tmp/${GO_TAR}"
rm -rf /usr/local/go
tar -C /usr/local -xzf "/tmp/${GO_TAR}"
rm "/tmp/${GO_TAR}"

# Set up Go environment
export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"

echo "Go: $(go version)"

#####################################
# Install Go tools
#####################################
echo "Installing Go tools..."
go install golang.org/x/tools/gopls@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/air-verse/air@latest

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
mkdir -p ~/go/{src,pkg,bin}
mkdir -p ~/tmp

#####################################
# Set up nice shell experience
#####################################
echo "Setting up shell..."
cat >> ~/.bashrc << 'EOF'

# Go environment
export GOROOT="/usr/local/go"
export GOPATH="$HOME/go"
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"

# Dev aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias gp='git pull'
alias gd='git diff'
alias ..='cd ..'
alias ...='cd ../..'

# Go aliases
alias gob='go build'
alias gor='go run'
alias got='go test'
alias gotv='go test -v'
alias goc='go clean'
alias gom='go mod'

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
        "go.useLanguageServer": true,
        "go.lintTool": "golangci-lint",
        "go.lintOnSave": "workspace",
        "[go]": {
            "editor.defaultFormatter": "golang.go",
            "editor.codeActionsOnSave": {
                "source.organizeImports": true
            }
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
echo "  Go $(go version | cut -d' ' -f3)"
echo "  Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
echo "  Git $(git --version | cut -d' ' -f3)"
echo "  sqlite3 $(sqlite3 --version | cut -d' ' -f1)"
echo ""
echo "Go tools installed:"
echo "  gopls           # Language server"
echo "  dlv             # Debugger (Delve)"
echo "  staticcheck     # Linter"
echo "  goimports       # Import formatter"
echo "  golangci-lint   # Meta-linter"
echo "  air             # Live reload"
echo ""
echo "Environment:"
echo "  GOROOT: $GOROOT"
echo "  GOPATH: $GOPATH"
echo ""
echo "Useful commands:"
echo "  go mod init github.com/user/repo  # init module"
echo "  go mod tidy                       # clean up deps"
echo "  go get package@version            # add dependency"
echo "  go build                          # build binary"
echo "  go run main.go                    # run file"
echo "  go test ./...                     # run all tests"
echo "  air                               # live reload server"
echo "  golangci-lint run                 # run linter"
echo ""
echo "Next steps:"
echo "  1. Install 'Go' extension in VS Code"
echo "  2. Press Cmd/Ctrl+Shift+P -> 'Remote-SSH: Connect to Host'"
echo "  3. Enter: root@<your-ip> (or use the host alias)"
echo "  4. Open ~/projects and start coding!"
echo ""
