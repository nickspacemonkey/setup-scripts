#!/bin/sh
set -eu

SETUP_URL=https://raw.githubusercontent.com/nickspacemonkey/setup-scripts/main/setup.sh
SETUP_FILE=""

cleanup() {
    if [ -n "$SETUP_FILE" ]; then
        rm -f -- "$SETUP_FILE"
    fi
}

trap cleanup EXIT HUP INT TERM

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

if ! command -v bash >/dev/null 2>&1; then
    echo "Bash is required; installing it now..."
    if command -v apk >/dev/null 2>&1; then
        apk add bash
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y bash
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y bash
    elif command -v pacman >/dev/null 2>&1; then
        pacman -S --needed --noconfirm bash
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install bash
    else
        echo "ERROR: Cannot install Bash: unsupported package manager."
        exit 1
    fi
fi

SETUP_FILE="$(mktemp)"
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$SETUP_URL" -o "$SETUP_FILE"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$SETUP_FILE" "$SETUP_URL"
else
    echo "ERROR: curl or wget is required to download setup.sh."
    exit 1
fi

bash "$SETUP_FILE" "$@"
