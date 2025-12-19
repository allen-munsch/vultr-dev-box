#!/usr/bin/env bash
set -eo pipefail
echo "==============================="
echo "🛠️  VS Code TypeScript Dev Setup"
echo "==============================="

#####################################
# Update system
#####################################
echo "📦 Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
echo 'source ~/.bashrc' >> ~/.bash_history

#####################################
# Install essential tools
#####################################
echo "🔧 Installing essential tools..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    wget \
    sqlite3 \
    tmux \
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
    bash-completion

#####################################
# Install nvm and Node.js
#####################################
echo "📦 Installing nvm..."
export NVM_DIR="$HOME/.nvm"
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Load nvm immediately
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

echo "📦 Installing Node.js LTS via nvm..."
nvm install --lts
nvm alias default lts/*

echo "➡️  Node: $(node --version)"
echo "➡️  npm:  $(npm --version)"

#####################################
# Install global npm packages
#####################################
echo "📦 Installing global npm packages..."
npm install -g \
    typescript \
    ts-node \
    tsx \
    @types/node \
    eslint \
    prettier \
    npm-check-updates \
    pnpm

echo "➡️  TypeScript: $(tsc --version)"
echo "➡️  pnpm:       $(pnpm --version)"

#####################################
# Install Docker (optional but handy)
#####################################
echo "🐳 Installing Docker..."
curl -fsSL https://get.docker.com | sh

#####################################
# Set up git defaults
#####################################
echo "🔧 Configuring git..."
git config --global init.defaultBranch main
git config --global core.editor "code --wait"
git config --global pull.rebase true

#####################################
# Create dev directories
#####################################
echo "📁 Creating dev directories..."
mkdir -p ~/projects
mkdir -p ~/tmp

#####################################
# Set up nice shell experience
#####################################
echo "🐚 Setting up shell..."
cat >> ~/.bashrc << 'EOF'

# Dev aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias gp='git pull'
alias gd='git diff'
alias ..='cd ..'
alias ...='cd ../..'

# Node/npm aliases
alias ni='npm install'
alias nr='npm run'
alias nt='npm test'

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
echo "📝 Creating VS Code workspace file..."
cat > ~/projects/workspace.code-workspace << 'EOF'
{
    "folders": [
        {
            "path": "."
        }
    ],
    "settings": {
        "editor.formatOnSave": true,
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "typescript.preferences.importModuleSpecifier": "relative"
    }
}
EOF

echo ""
echo "==============================="
echo "✅ Setup Complete!"
echo "==============================="
echo ""
echo "Installed:"
echo "  • nvm $(nvm --version)"
echo "  • Node.js $(node --version)"
echo "  • TypeScript $(tsc --version)"
echo "  • pnpm $(pnpm --version)"
echo "  • Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
echo "  • Git $(git --version | cut -d' ' -f3)"
echo ""
echo "nvm commands:"
echo "  nvm ls              # list installed versions"
echo "  nvm ls-remote       # list available versions"
echo "  nvm install 20      # install Node 20"
echo "  nvm use 20          # switch to Node 20"
echo ""
echo "Next steps:"
echo "  1. Install 'Remote - SSH' extension in VS Code"
echo "  2. Press Cmd/Ctrl+Shift+P → 'Remote-SSH: Connect to Host'"
echo "  3. Enter: root@<your-ip> (or use the host alias)"
echo "  4. Open ~/projects and start coding!"
echo ""
