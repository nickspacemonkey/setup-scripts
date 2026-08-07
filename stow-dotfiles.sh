#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

REPOS=(
    "$SCRIPT_DIR/dotfiles"
    "$SCRIPT_DIR/fishfiles"
)

for repo in "${REPOS[@]}"; do
    if [[ ! -d "$repo" ]]; then
        echo "Skipping '$repo' (directory not found)"
        continue
    fi

    echo "Stowing $repo..."
    (
        cd "$repo"
        stow --target="$HOME" .
    )
done

echo "Done."
