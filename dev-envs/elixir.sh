#!/usr/bin/env bash
set -eo pipefail
echo "==============================="
echo "Elixir Dev Environment Setup"
echo "==============================="

#####################################
# Update system
#####################################
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

#####################################
# Install essential tools and Erlang dependencies
#####################################
echo "Installing essential tools and Erlang dependencies..."
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
    autoconf \
    m4 \
    libncurses5-dev \
    libwxgtk3.2-dev \
    libwxgtk-webview3.2-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libpng-dev \
    libssh-dev \
    unixodbc-dev \
    xsltproc \
    fop \
    libxml2-utils \
    libncurses-dev \
    openjdk-11-jdk \
    libssl-dev \
    sqlite3 \
    libsqlite3-dev

#####################################
# Install asdf
#####################################
echo "Installing asdf..."
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1

# Load asdf immediately
. "$HOME/.asdf/asdf.sh"
. "$HOME/.asdf/completions/asdf.bash"

# Add to bashrc
cat >> ~/.bashrc << 'EOF'

# asdf
. "$HOME/.asdf/asdf.sh"
. "$HOME/.asdf/completions/asdf.bash"
EOF

#####################################
# Install Erlang plugin and Erlang
#####################################
echo "Installing Erlang plugin..."
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git

echo "Installing Erlang 27.1.2 (this may take several minutes)..."
asdf install erlang 27.1.2
asdf global erlang 27.1.2

echo "Erlang: $(erl -eval '{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().' -noshell)"

#####################################
# Install Elixir plugin and Elixir
#####################################
echo "Installing Elixir plugin..."
asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git

echo "Installing Elixir 1.17.3..."
asdf install elixir 1.17.3-otp-27
asdf global elixir 1.17.3-otp-27

echo "Elixir: $(elixir --version | grep Elixir)"

#####################################
# Install Hex and Rebar
#####################################
echo "Installing Hex and Rebar..."
mix local.hex --force
mix local.rebar --force

#####################################
# Install Phoenix
#####################################
echo "Installing Phoenix..."
mix archive.install hex phx_new --force

#####################################
# Install Node.js for Phoenix assets (via asdf)
#####################################
echo "Installing Node.js plugin..."
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git

echo "Installing Node.js LTS..."
asdf install nodejs lts
asdf global nodejs lts

echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"

#####################################
# Install PostgreSQL for Phoenix projects
#####################################
echo "Installing PostgreSQL..."
DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql postgresql-contrib

# Start PostgreSQL
service postgresql start

# Create default postgres user
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"

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

# Elixir/Phoenix aliases
alias mt='mix test'
alias mc='mix compile'
alias mf='mix format'
alias ms='mix phx.server'
alias mig='mix ecto.migrate'
alias migs='mix ecto.setup'
alias migd='mix ecto.reset'

# iex aliases
alias iex='iex -S mix'

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
        "[elixir]": {
            "editor.defaultFormatter": "JakeBecker.elixir-ls",
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
echo "  asdf $(asdf version | cut -d' ' -f1)"
echo "  Erlang $(erl -eval '{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().' -noshell 2>/dev/null)"
echo "  Elixir $(elixir --version | grep Elixir | cut -d' ' -f2)"
echo "  Phoenix $(mix phx.new --version)"
echo "  Node.js $(node --version)"
echo "  PostgreSQL $(psql --version | cut -d' ' -f3)"
echo "  Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
echo "  Git $(git --version | cut -d' ' -f3)"
echo "  sqlite3 $(sqlite3 --version | cut -d' ' -f1)"
echo ""
echo "asdf commands:"
echo "  asdf list                    # list installed versions"
echo "  asdf list all erlang         # list available Erlang versions"
echo "  asdf list all elixir         # list available Elixir versions"
echo "  asdf install erlang 27.0     # install specific Erlang version"
echo "  asdf install elixir 1.17.0   # install specific Elixir version"
echo "  asdf global erlang 27.0      # set global version"
echo "  asdf local elixir 1.17.0     # set version for current dir"
echo ""
echo "Mix/Phoenix commands:"
echo "  mix phx.new myapp            # create new Phoenix app"
echo "  mix phx.new myapp --no-ecto  # without database"
echo "  mix deps.get                 # get dependencies"
echo "  mix ecto.create              # create database"
echo "  mix ecto.migrate             # run migrations"
echo "  mix phx.server               # start dev server"
echo "  mix test                     # run tests"
echo "  mix format                   # format code"
echo "  iex -S mix                   # interactive shell"
echo ""
echo "PostgreSQL info:"
echo "  Default user: postgres"
echo "  Default password: postgres"
echo "  Connection: postgresql://postgres:postgres@localhost/myapp_dev"
echo ""
echo "Next steps:"
echo "  1. Install 'ElixirLS' extension in VS Code"
echo "  2. Press Cmd/Ctrl+Shift+P -> 'Remote-SSH: Connect to Host'"
echo "  3. Enter: root@<your-ip> (or use the host alias)"
echo "  4. Open ~/projects and start coding!"
echo "  5. Create a Phoenix app: mix phx.new myapp"
echo ""
