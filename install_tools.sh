#!/usr/bin/env bash
set -euo pipefail

install_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y \
            git \
            tmux \
            fish \
            stow

    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y \
            git \
            tmux \
            fish \
            stow

    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y \
            git \
            tmux \
            fish \
            stow

    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm \
            git \
            tmux \
            fish \
            stow

    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper --non-interactive install \
            git \
            tmux \
            fish \
            stow

    elif command -v apk >/dev/null 2>&1; then
        sudo apk add \
            git \
            tmux \
            fish \
            stow

    else
        echo "ERROR: Unsupported package manager."
        exit 1
    fi
}

echo "Installing git, tmux, fish, and stow..."
install_packages

echo
echo "Installed versions:"
echo "-------------------"
command -v git >/dev/null && git --version
command -v tmux >/dev/null && tmux -V
command -v fish >/dev/null && fish --version
command -v stow >/dev/null && stow --version | head -n1

echo
echo "Installation complete."
