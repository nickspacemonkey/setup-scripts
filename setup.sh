#!/usr/bin/env bash
set -uo pipefail

shopt -s nullglob

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install_tools.sh"

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

# Run all other .sh scripts
for script in "$SCRIPT_DIR"/*.sh; do
    case "$script" in
        "$SCRIPT_DIR/$(basename "$0")"|"$INSTALL_SCRIPT")
            continue
            ;;
    esac

    echo "Running $script..."
    if ! bash "$script"; then
        echo "ERROR: $script failed."
    fi
done

echo "All scripts processed."
