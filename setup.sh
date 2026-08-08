#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HELPER_DIR="$SCRIPT_DIR/scripts"
INSTALL_SCRIPT="$HELPER_DIR/install_tools.sh"
SETUP_SCRIPTS=(
    "$HELPER_DIR/setup-authorized-keys.sh"
    "$HELPER_DIR/harden-ssh.sh"
    "$HELPER_DIR/setup-passwordless-sudo.sh"
    "$HELPER_DIR/stow-dotfiles.sh"
)

read -r -p "Enter the username to configure: " TARGET_USER

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
        sudo useradd --create-home --shell /bin/bash -- "$TARGET_USER"
    elif command -v adduser >/dev/null 2>&1; then
        sudo adduser -D -s /bin/bash "$TARGET_USER"
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
