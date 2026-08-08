#!/usr/bin/env bash
set -uo pipefail

if (( EUID != 0 )); then
    echo "ERROR: This script must be run as root (for example: sudo bash setup.sh)."
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HELPER_DIR="$SCRIPT_DIR/scripts"
INSTALL_SCRIPT="$HELPER_DIR/install_tools.sh"
REPOSITORY_URL="https://github.com/nickspacemonkey/setup-scripts.git"
DEFAULT_CHECKOUT="${HOME}/.local/src/setup-scripts"
SETUP_SCRIPTS=(
    "$HELPER_DIR/setup-authorized-keys.sh"
    "$HELPER_DIR/harden-ssh.sh"
    "$HELPER_DIR/setup-passwordless-sudo.sh"
    "$HELPER_DIR/stow-dotfiles.sh"
)

install_git() {
    command -v git >/dev/null 2>&1 && return

    echo "Git is required; installing it now..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y git
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y git
    elif command -v yum >/dev/null 2>&1; then
        yum install -y git
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm git
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install git
    elif command -v apk >/dev/null 2>&1; then
        apk add git
    else
        echo "ERROR: Cannot install Git: unsupported package manager."
        return 1
    fi
}

bootstrap_repository() {
    local checkout="${SETUP_SCRIPTS_CHECKOUT:-$DEFAULT_CHECKOUT}"
    local bootstrap_user

    read -r -p "Enter the username to configure: " bootstrap_user

    if [[ -z "$bootstrap_user" ]]; then
        echo "ERROR: A username is required."
        exit 1
    fi

    if [[ ! "$bootstrap_user" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
        echo "ERROR: '$bootstrap_user' is not a valid username."
        exit 1
    fi

    if ! install_git; then
        echo "ERROR: Failed to install Git."
        exit 1
    fi

    if [[ -e "$checkout" ]]; then
        if [[ ! -d "$checkout/.git" ]] || [[ ! -f "$checkout/setup.sh" ]]; then
            echo "ERROR: Bootstrap destination already exists and is not a setup-scripts checkout: $checkout"
            exit 1
        fi
        echo "Using existing setup-scripts checkout at $checkout..."
    else
        echo "Cloning setup-scripts into $checkout..."
        mkdir -p -- "$(dirname -- "$checkout")"
        if ! git clone "$REPOSITORY_URL" "$checkout"; then
            echo "ERROR: Failed to clone $REPOSITORY_URL."
            exit 1
        fi
    fi

    exec bash "$checkout/setup.sh" "$bootstrap_user" "$@"
}

# A downloaded copy of setup.sh can bootstrap the complete repository.
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
    bootstrap_repository "$@"
fi

if (( $# > 0 )); then
    TARGET_USER="$1"
    shift
else
    read -r -p "Enter the username to configure: " TARGET_USER
fi

if [[ -z "$TARGET_USER" ]]; then
    echo "ERROR: A username is required."
    exit 1
fi

if [[ ! "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
    echo "ERROR: '$TARGET_USER' is not a valid username."
    exit 1
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "Creating user '$TARGET_USER'..."
    if command -v useradd >/dev/null 2>&1; then
        useradd --create-home --shell /bin/bash -- "$TARGET_USER"
    elif command -v adduser >/dev/null 2>&1; then
        adduser -D -s /bin/bash "$TARGET_USER"
    else
        echo "ERROR: Neither useradd nor adduser is available."
        exit 1
    fi
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "ERROR: Failed to create user '$TARGET_USER'."
    exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [[ -z "$TARGET_HOME" ]] || [[ ! -d "$TARGET_HOME" ]]; then
    echo "ERROR: Home directory for '$TARGET_USER' was not found."
    exit 1
fi

export TARGET_USER TARGET_HOME

# Run install_tools.sh first
if [[ -f "$INSTALL_SCRIPT" ]]; then
    echo "Running $INSTALL_SCRIPT..."
    if ! bash "$INSTALL_SCRIPT"; then
        echo "ERROR: $INSTALL_SCRIPT failed."
        exit 1
    fi
else
    echo "ERROR: $INSTALL_SCRIPT not found."
    exit 1
fi

# Initialize bundled configuration repositories after installing required tools
echo "Initializing Git submodules..."
if ! git -C "$SCRIPT_DIR" submodule update --init --recursive; then
    echo "ERROR: Failed to initialize Git submodules."
    exit 1
fi

# Run the remaining helper scripts in order
failed=0
for script in "${SETUP_SCRIPTS[@]}"; do
    if [[ ! -f "$script" ]]; then
        echo "ERROR: $script not found."
        failed=1
        continue
    fi

    echo "Running $script..."
    if ! bash "$script"; then
        echo "ERROR: $script failed."
        failed=1
    fi
done

if (( failed != 0 )); then
    echo "ERROR: One or more setup scripts failed."
    exit 1
fi

echo "All scripts processed."
