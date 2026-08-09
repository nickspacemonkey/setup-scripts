#!/usr/bin/env bash
set -euo pipefail

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
