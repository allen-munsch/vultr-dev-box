# Vultr Dev Tools

A collection of scripts for quickly spinning up development environments on Vultr cloud instances.

## Why

Setting up a remote development environment usually involves:
- Creating the instance
- Configuring SSH keys
- Installing language runtimes and tools
- Setting up editors and shells
- Copying files back and forth

These scripts automate all of that, letting you go from zero to a fully configured dev environment in under 5 minutes.

## Quick Start

### 1. Install Vultr CLI

```bash
./build-vultr.sh
```

### 2. Configure API Key

Get your API key from https://my.vultr.com/settings/#settingsapi

```bash
mkdir -p ~/.auth
echo "your-api-key-here" > ~/.auth/vultr
# OR
# export VULTR_API_KEY=your-api-key
```

Just a note on key security, it might be good to only allow API key usage from your ip address, something like:

```
echo $(curl -sq 'https://api.ipify.org?format=json' | jq -r .ip)/32
```

### 3. Create an Instance

```bash
./deploy-dev-box.sh
```

This will:
- Generate a dedicated SSH key for the instance
- Create a Vultr instance (Ubuntu 24.04)
- Add it to your SSH config `~/.ssh/config`
- Connect you automatically when ready

### 4. Set Up Your Dev Environment

Once connected to your instance, run one of the setup scripts:

```bash
# to source vscp/vfwd completions

source ./completions/complete.sh

# For TypeScript/Node.js development
vscp ./dev-envs/typescript.sh tiny-box-123456789 --run

# For Python development, example of tab completing on a tiny box name
./vscp ./dev-envs/python.sh <tab> ti <tab>

# For Rust development
./vscp ./dev-envs/rust.sh tiny-box-123456789  --run

# For Go development
./vscp ./dev-envs/golang.sh tiny-box-123456789 --run

# For Elixir development
./vscp ./dev-envs/elixir.sh tiny-box-123456789 --run
```

### 5. Use Helper Tools

**Copy files to instance:**
```bash
vscp ./myfile.txt tiny-box-123456789
vscp ./script.sh tiny-box-123456789 --run
```

**Forward ports (for accessing services):**
```bash
./vfwd tiny-box-123456789 8080
./vfwd tiny-box-123456789 8080 3000
./vfwd tiny-box-123456789 8080,3000,5173
```

**Install bash completions:**
```bash
./completions/complete.sh
```

## Available Scripts

### Instance Management
- `deploy-dev-box.sh` - Create and configure a new Vultr instance
- `build-vultr.sh` - Build and install the Vultr CLI from source

### Dev Environment Setup
- `dev-envs/typescript.sh` - Node.js, TypeScript, pnpm, Docker
- `dev-envs/python.sh` - pyenv, uv, common Python tools
- `dev-envs/rust.sh` - rustup, cargo, common Rust tools
- `dev-envs/golang.sh` - Go toolchain, common Go tools
- `dev-envs/elixir.sh` - asdf, Erlang, Elixir, Phoenix

### Utilities
- `vfwd` - SSH port forwarding helper
- `vscp` - SCP wrapper for copying files
- `dev-envs/mini-serve.sh` - Quick HTTP server on any port

## Requirements

- Bash 4+
- curl, git, jq
- Vultr account and API key

## Configuration

Default instance settings in `deploy-dev-box.sh`:
- Region: New Jersey (ewr)
- Plan: vc2-1c-1gb ($5/month)
- OS: Ubuntu 24.04 LTS

Edit the script to change these defaults.

## SSH Keys

Each instance gets its own SSH key stored in `~/.ssh/vultr/<instance-label>`. This makes it easy to manage and clean up instances independently.

## Visual Studio Code

It works great with the remote ssh plugin!

## License

MIT
