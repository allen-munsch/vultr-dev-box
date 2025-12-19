#!/bin/bash
#
# Forgejo Admin Helper Script
# Interactive tool for common administration tasks
#

set -euo pipefail

# Configuration - adjust if your paths differ
FORGEJO_BIN="/usr/local/bin/forgejo"
FORGEJO_WORK_DIR="/var/lib/forgejo"
FORGEJO_CONFIG="/etc/forgejo/app.ini"
FORGEJO_USER="git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Run forgejo command as git user
forgejo_cmd() {
    sudo -u "${FORGEJO_USER}" "${FORGEJO_BIN}" \
        --work-path "${FORGEJO_WORK_DIR}" \
        --config "${FORGEJO_CONFIG}" \
        "$@"
}

# Prompt for password securely (no echo)
prompt_password() {
    local prompt="${1:-Password}"
    local password
    local password_confirm
    
    while true; do
        read -rsp "${prompt}: " password
        echo
        
        if [[ -z "$password" ]]; then
            echo -e "${RED}Password cannot be empty${NC}"
            continue
        fi
        
        if [[ ${#password} -lt 8 ]]; then
            echo -e "${RED}Password must be at least 8 characters${NC}"
            continue
        fi
        
        read -rsp "Confirm password: " password_confirm
        echo
        
        if [[ "$password" != "$password_confirm" ]]; then
            echo -e "${RED}Passwords do not match${NC}"
            continue
        fi
        
        break
    done
    
    echo "$password"
}

# Generate a random password
generate_password() {
    local length="${1:-16}"
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c "$length"
}

# Create a new user
create_user() {
    echo -e "${BLUE}=== Create New User ===${NC}"
    echo
    
    read -rp "Username: " username
    if [[ -z "$username" ]]; then
        echo -e "${RED}Username cannot be empty${NC}"
        return 1
    fi
    
    read -rp "Email: " email
    if [[ -z "$email" ]]; then
        echo -e "${RED}Email cannot be empty${NC}"
        return 1
    fi
    
    read -rp "Make admin? [y/N]: " is_admin
    
    echo
    echo "Password options:"
    echo "  1) Enter password manually"
    echo "  2) Generate random password"
    read -rp "Choose [1/2]: " pw_choice
    
    case "$pw_choice" in
        2)
            password=$(generate_password 16)
            echo
            echo -e "${GREEN}Generated password:${NC} $password"
            echo -e "${YELLOW}Save this password - it won't be shown again!${NC}"
            echo
            ;;
        *)
            password=$(prompt_password "Password")
            ;;
    esac
    
    # Build command
    local cmd=(admin user create --username "$username" --email "$email" --password "$password")
    
    if [[ "$is_admin" =~ ^[Yy] ]]; then
        cmd+=(--admin)
    fi
    
    echo
    echo "Creating user..."
    if forgejo_cmd "${cmd[@]}"; then
        echo -e "${GREEN}User '$username' created successfully${NC}"
    else
        echo -e "${RED}Failed to create user${NC}"
        return 1
    fi
}

# Change user password
change_password() {
    echo -e "${BLUE}=== Change User Password ===${NC}"
    echo
    
    # List users for reference
    echo "Current users:"
    forgejo_cmd admin user list
    echo
    
    read -rp "Username: " username
    if [[ -z "$username" ]]; then
        echo -e "${RED}Username cannot be empty${NC}"
        return 1
    fi
    
    echo
    echo "Password options:"
    echo "  1) Enter password manually"
    echo "  2) Generate random password"
    read -rp "Choose [1/2]: " pw_choice
    
    case "$pw_choice" in
        2)
            password=$(generate_password 16)
            echo
            echo -e "${GREEN}Generated password:${NC} $password"
            echo -e "${YELLOW}Save this password - it won't be shown again!${NC}"
            echo
            ;;
        *)
            password=$(prompt_password "New password")
            ;;
    esac
    
    echo
    echo "Changing password..."
    if forgejo_cmd admin user change-password --username "$username" --password "$password"; then
        echo -e "${GREEN}Password changed successfully${NC}"
    else
        echo -e "${RED}Failed to change password${NC}"
        return 1
    fi
}

# List users
list_users() {
    echo -e "${BLUE}=== User List ===${NC}"
    echo
    forgejo_cmd admin user list
}

# Delete user
delete_user() {
    echo -e "${BLUE}=== Delete User ===${NC}"
    echo
    
    # List users for reference
    echo "Current users:"
    forgejo_cmd admin user list
    echo
    
    read -rp "Username to delete: " username
    if [[ -z "$username" ]]; then
        echo -e "${RED}Username cannot be empty${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}WARNING: This will permanently delete user '$username' and all their data!${NC}"
    read -rp "Type username again to confirm: " confirm
    
    if [[ "$confirm" != "$username" ]]; then
        echo "Aborted"
        return 1
    fi
    
    echo
    echo "Deleting user..."
    if forgejo_cmd admin user delete --username "$username"; then
        echo -e "${GREEN}User '$username' deleted${NC}"
    else
        echo -e "${RED}Failed to delete user${NC}"
        return 1
    fi
}

# Generate admin access token
generate_token() {
    echo -e "${BLUE}=== Generate Access Token ===${NC}"
    echo
    
    echo "Current users:"
    forgejo_cmd admin user list
    echo
    
    read -rp "Username: " username
    if [[ -z "$username" ]]; then
        echo -e "${RED}Username cannot be empty${NC}"
        return 1
    fi
    
    read -rp "Token name: " token_name
    if [[ -z "$token_name" ]]; then
        token_name="admin-token-$(date +%Y%m%d)"
    fi
    
    read -rp "Scopes (comma-separated, e.g., all,read:user): " scopes
    if [[ -z "$scopes" ]]; then
        scopes="all"
    fi
    
    echo
    echo "Generating token..."
    forgejo_cmd admin user generate-access-token \
        --username "$username" \
        --token-name "$token_name" \
        --scopes "$scopes"
}

# Regenerate hooks
regenerate_hooks() {
    echo -e "${BLUE}=== Regenerate Git Hooks ===${NC}"
    echo
    echo "Regenerating hooks for all repositories..."
    
    if forgejo_cmd admin regenerate hooks; then
        echo -e "${GREEN}Hooks regenerated successfully${NC}"
    else
        echo -e "${RED}Failed to regenerate hooks${NC}"
        return 1
    fi
}

# Regenerate keys
regenerate_keys() {
    echo -e "${BLUE}=== Regenerate Authorized Keys ===${NC}"
    echo
    echo "Regenerating SSH authorized_keys file..."
    
    if forgejo_cmd admin regenerate keys; then
        echo -e "${GREEN}Keys regenerated successfully${NC}"
    else
        echo -e "${RED}Failed to regenerate keys${NC}"
        return 1
    fi
}

# Service management
service_menu() {
    echo -e "${BLUE}=== Service Management ===${NC}"
    echo
    echo "1) Status"
    echo "2) Start"
    echo "3) Stop"
    echo "4) Restart"
    echo "5) View logs (last 50 lines)"
    echo "6) Follow logs (Ctrl+C to stop)"
    echo "0) Back"
    echo
    read -rp "Choose: " choice
    
    case "$choice" in
        1) systemctl status forgejo ;;
        2) sudo systemctl start forgejo && echo -e "${GREEN}Started${NC}" ;;
        3) sudo systemctl stop forgejo && echo -e "${GREEN}Stopped${NC}" ;;
        4) sudo systemctl restart forgejo && echo -e "${GREEN}Restarted${NC}" ;;
        5) journalctl -u forgejo -n 50 --no-pager ;;
        6) journalctl -u forgejo -f ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
}

# Show help
show_help() {
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "  create-user      Create a new user"
    echo "  change-password  Change user password"
    echo "  list-users       List all users"
    echo "  delete-user      Delete a user"
    echo "  generate-token   Generate access token"
    echo "  regen-hooks      Regenerate git hooks"
    echo "  regen-keys       Regenerate SSH keys"
    echo "  service          Service management"
    echo "  help             Show this help"
    echo
    echo "Run without arguments for interactive menu."
}

# Main menu
main_menu() {
    while true; do
        echo
        echo -e "${BLUE}================================${NC}"
        echo -e "${BLUE}    Forgejo Admin Helper${NC}"
        echo -e "${BLUE}================================${NC}"
        echo
        echo "User Management:"
        echo "  1) Create user"
        echo "  2) Change password"
        echo "  3) List users"
        echo "  4) Delete user"
        echo "  5) Generate access token"
        echo
        echo "Maintenance:"
        echo "  6) Regenerate git hooks"
        echo "  7) Regenerate SSH keys"
        echo "  8) Service management"
        echo
        echo "  0) Exit"
        echo
        read -rp "Choose: " choice
        
        case "$choice" in
            1) create_user ;;
            2) change_password ;;
            3) list_users ;;
            4) delete_user ;;
            5) generate_token ;;
            6) regenerate_hooks ;;
            7) regenerate_keys ;;
            8) service_menu ;;
            0) echo "Bye!"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
    done
}

# Main entry point
main() {
    # Check if running as root or with sudo access
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}This script requires sudo access${NC}"
    fi
    
    # Handle command line arguments
    case "${1:-}" in
        create-user)     create_user ;;
        change-password) change_password ;;
        list-users)      list_users ;;
        delete-user)     delete_user ;;
        generate-token)  generate_token ;;
        regen-hooks)     regenerate_hooks ;;
        regen-keys)      regenerate_keys ;;
        service)         service_menu ;;
        help|--help|-h)  show_help ;;
        "")              main_menu ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"