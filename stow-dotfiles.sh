#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${TARGET_USER:-}" ]] || [[ -z "${TARGET_HOME:-}" ]]; then
    echo "ERROR: TARGET_USER and TARGET_HOME must be set."
    exit 1
fi

EXPECTED_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [[ -z "$EXPECTED_HOME" ]] || [[ "$TARGET_HOME" != "$EXPECTED_HOME" ]]; then
    echo "ERROR: TARGET_HOME does not match the home directory for '$TARGET_USER'."
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

    echo "Stowing $repo into $TARGET_HOME..."
    sudo -H -u "$TARGET_USER" \
        env HOME="$TARGET_HOME" \
        stow --dir="$repo" --target="$TARGET_HOME" .
done

echo "Done."
