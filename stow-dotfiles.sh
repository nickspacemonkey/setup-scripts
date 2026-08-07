#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${TARGET_USER:-}" ]] || [[ -z "${TARGET_HOME:-}" ]]; then
    echo "ERROR: TARGET_USER and TARGET_HOME must be set."
    exit 1
fi

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
        sudo -u "$TARGET_USER" stow --target="$TARGET_HOME" .
    )
done

echo "Done."
