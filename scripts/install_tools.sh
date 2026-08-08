#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    echo "ERROR: This script must be run as root."
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UNATTENDED_UPGRADES_CONFIG="$SCRIPT_DIR/../config/apt/50unattended-upgrades"
AUTO_UPGRADES_CONFIG="$SCRIPT_DIR/../config/apt/20auto-upgrades"

is_debian() {
    [[ -r /etc/os-release ]] || return 1

    local ID
    ID="$(. /etc/os-release && printf '%s' "${ID:-}")"
    [[ "$ID" == "debian" ]]
}

install_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh-server

        if is_debian; then
            if [[ ! -f "$UNATTENDED_UPGRADES_CONFIG" ]] || [[ ! -f "$AUTO_UPGRADES_CONFIG" ]]; then
                echo "ERROR: Bundled unattended-upgrades configuration is incomplete."
                exit 1
            fi

            apt-get install -y unattended-upgrades
            install -m 0644 \
                "$AUTO_UPGRADES_CONFIG" \
                /etc/apt/apt.conf.d/20auto-upgrades
            install -m 0644 \
                "$UNATTENDED_UPGRADES_CONFIG" \
                /etc/apt/apt.conf.d/50unattended-upgrades
        fi

    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh-server

    elif command -v yum >/dev/null 2>&1; then
        yum install -y \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh-server

    elif command -v pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh

    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh-server

    elif command -v apk >/dev/null 2>&1; then
        apk add \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh-server

    else
        echo "ERROR: Unsupported package manager."
        exit 1
    fi
}

echo "Installing sudo, Git, tmux, fish, stow, and OpenSSH server..."
install_packages

echo
echo "Installed versions:"
echo "-------------------"
command -v sudo >/dev/null && sudo --version | sed -n '1p'
command -v git >/dev/null && git --version
command -v tmux >/dev/null && tmux -V
command -v fish >/dev/null && fish --version
command -v stow >/dev/null && stow --version | head -n1
command -v sshd >/dev/null && sshd -V 2>&1 | sed -n '1p'

echo
echo "Installation complete."
