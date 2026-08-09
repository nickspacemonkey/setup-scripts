#!/usr/bin/env bash
set -euo pipefail

configure_ollama_host() {
    install -d -m 0755 /etc/profile.d /etc/fish/conf.d
    printf '%s\n' 'export OLLAMA_HOST=http://192.168.0.2:11434' \
        > /etc/profile.d/ollama-host.sh
    printf '%s\n' 'set -gx OLLAMA_HOST http://192.168.0.2:11434' \
        > /etc/fish/conf.d/ollama-host.fish
    chmod 0644 /etc/profile.d/ollama-host.sh /etc/fish/conf.d/ollama-host.fish
    echo "Configured Ollama clients to use http://192.168.0.2:11434."
}

ensure_zstd() {
    if command -v zstd >/dev/null 2>&1; then
        echo "zstd is already installed."
        return
    fi

    echo "zstd is required by the Ollama installer; installing it now..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y zstd
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y zstd
    elif command -v pacman >/dev/null 2>&1; then
        pacman -S --needed --noconfirm zstd
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install zstd
    elif command -v apk >/dev/null 2>&1; then
        apk add zstd
    else
        echo "ERROR: Cannot install zstd: unsupported package manager."
        return 1
    fi

    if ! command -v zstd >/dev/null 2>&1; then
        echo "ERROR: zstd installation completed without providing the zstd command."
        return 1
    fi
}

if (( EUID != 0 )); then
    echo "ERROR: This script must be run as root."
    exit 1
fi

ensure_zstd

if command -v ollama >/dev/null 2>&1; then
    echo "Ollama is already installed."
    ollama --version
    configure_ollama_host
    exit 0
fi

echo "Installing Ollama..."
if ! curl -fsSL https://ollama.com/install.sh | sh; then
    echo "ERROR: Ollama installation failed."
    exit 1
fi

ollama --version
configure_ollama_host
echo "Ollama installation complete."
