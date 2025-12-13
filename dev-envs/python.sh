#!/usr/bin/env bash
set -eo pipefail
echo "==============================="
echo "Python Dev Environment Setup"
echo "==============================="

#####################################
# Update system
#####################################
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

#####################################
# Install essential tools and Python build dependencies
#####################################
echo "Installing essential tools and Python dependencies..."
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
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    sqlite3

#####################################
# Install pyenv
#####################################
echo "Installing pyenv..."
export PYENV_ROOT="$HOME/.pyenv"
curl -fsSL https://pyenv.run | bash

# Load pyenv immediately
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Add to bashrc
cat >> ~/.bashrc << 'EOF'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF

#####################################
# Install Python versions
#####################################
echo "Installing Python 3.12 (latest stable)..."
pyenv install 3.12
pyenv global 3.12

echo "Python: $(python --version)"
echo "pip: $(pip --version)"

#####################################
# Upgrade pip and install uv
#####################################
echo "Upgrading pip and installing uv..."
pip install --upgrade pip setuptools wheel
curl -LsSf https://astral.sh/uv/install.sh | sh

# Add uv to PATH
export PATH="$HOME/.cargo/bin:$PATH"
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc

echo "uv: $(uv --version)"

#####################################
# Install global Python tools
#####################################
echo "Installing global Python tools..."
pip install \
    black \
    isort \
    flake8 \
    pylint \
    mypy \
    pytest \
    pytest-cov \
    ipython \
    jupyter \
    httpie

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

# Dev aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias gp='git pull'
alias gd='git diff'
alias ..='cd ..'
alias ...='cd ../..'

# Python aliases
alias py='python'
alias ipy='ipython'
alias ptest='pytest -v'
alias pcov='pytest --cov'

# uv aliases
alias uvi='uv pip install'
alias uvs='uv venv && source .venv/bin/activate'
alias uva='source .venv/bin/activate'

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
        "python.formatting.provider": "black",
        "python.linting.enabled": true,
        "python.linting.pylintEnabled": true,
        "python.linting.flake8Enabled": true,
        "python.testing.pytestEnabled": true,
        "[python]": {
            "editor.defaultFormatter": "ms-python.black-formatter",
            "editor.formatOnSave": true,
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
echo "  Python $(python --version | cut -d' ' -f2)"
echo "  uv $(uv --version | cut -d' ' -f2)"
echo "  pip $(pip --version | cut -d' ' -f2)"
echo "  Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
echo "  Git $(git --version | cut -d' ' -f3)"
echo "  sqlite3 $(sqlite3 --version | cut -d' ' -f1)"
echo ""
echo "pyenv commands:"
echo "  pyenv versions          # list installed versions"
echo "  pyenv install --list    # list available versions"
echo "  pyenv install 3.11      # install Python 3.11"
echo "  pyenv global 3.11       # set global version"
echo "  pyenv local 3.11        # set version for current directory"
echo ""
echo "uv commands:"
echo "  uv venv                 # create virtual environment"
echo "  uv pip install requests # install package"
echo "  uv pip install -r requirements.txt # install from requirements"
echo "  uv pip compile pyproject.toml -o requirements.txt # compile deps"
echo "  uv pip sync requirements.txt # sync to exact requirements"
echo ""
echo "Next steps:"
echo "  1. Install 'Python' extension in VS Code"
echo "  2. Press Cmd/Ctrl+Shift+P -> 'Remote-SSH: Connect to Host'"
echo "  3. Enter: root@<your-ip> (or use the host alias)"
echo "  4. Open ~/projects and start coding!"
echo ""
