#!/usr/bin/env bash
set -uo pipefail

shopt -s nullglob

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install_tools.sh"

read -r -p "Enter the username to configure: " TARGET_USER

if [[ -z "$TARGET_USER" ]] || ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "ERROR: User '$TARGET_USER' does not exist."
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

# Initialize bundled configuration repositories after Git is installed
echo "Initializing Git submodules..."
if ! git -C "$SCRIPT_DIR" submodule update --init --recursive; then
    echo "ERROR: Failed to initialize Git submodules."
    exit 1
fi

# Run all other .sh scripts
failed=0
for script in "$SCRIPT_DIR"/*.sh; do
    case "$script" in
        "$SCRIPT_DIR/$(basename "$0")"|"$INSTALL_SCRIPT")
            continue
            ;;
    esac

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
