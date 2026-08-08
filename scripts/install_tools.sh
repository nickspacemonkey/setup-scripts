#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UNATTENDED_UPGRADES_CONFIG="$SCRIPT_DIR/../config/apt/50unattended-upgrades"

is_debian() {
    [[ -r /etc/os-release ]] || return 1

    local ID
    ID="$(. /etc/os-release && printf '%s' "${ID:-}")"
    [[ "$ID" == "debian" ]]
}

install_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y \
            sudo \
            tmux \
            fish \
            stow

        if is_debian; then
            if [[ ! -f "$UNATTENDED_UPGRADES_CONFIG" ]]; then
                echo "ERROR: Unattended-upgrades config not found: $UNATTENDED_UPGRADES_CONFIG"
                exit 1
            fi

            sudo apt-get install -y unattended-upgrades
            sudo install -m 0644 \
                "$UNATTENDED_UPGRADES_CONFIG" \
                /etc/apt/apt.conf.d/50unattended-upgrades
        fi

    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y \
            sudo \
            tmux \
            fish \
            stow

    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y \
            sudo \
            tmux \
            fish \
            stow

    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Syu --noconfirm \
            sudo \
            tmux \
            fish \
            stow

    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper --non-interactive install \
            sudo \
            tmux \
            fish \
            stow

    elif command -v apk >/dev/null 2>&1; then
        sudo apk add \
            sudo \
            tmux \
            fish \
            stow

    else
        echo "ERROR: Unsupported package manager."
        exit 1
    fi
}

echo "Installing sudo, tmux, fish, and stow..."
install_packages

echo
echo "Installed versions:"
echo "-------------------"
command -v sudo >/dev/null && sudo --version | sed -n '1p'
command -v tmux >/dev/null && tmux -V
command -v fish >/dev/null && fish --version
command -v stow >/dev/null && stow --version | head -n1

echo
echo "Installation complete."
