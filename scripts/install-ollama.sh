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

if (( EUID != 0 )); then
    echo "ERROR: This script must be run as root."
    exit 1
fi

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
