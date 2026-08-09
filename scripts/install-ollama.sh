#!/usr/bin/env bash
set -euo pipefail

if command -v ollama >/dev/null 2>&1; then
    echo "Ollama is already installed."
    ollama --version
    exit 0
fi

if (( EUID != 0 )); then
    echo "ERROR: This script must be run as root."
    exit 1
fi

echo "Installing Ollama..."
if ! curl -fsSL https://ollama.com/install.sh | sh; then
    echo "ERROR: Ollama installation failed."
    exit 1
fi

ollama --version
echo "Ollama installation complete."
