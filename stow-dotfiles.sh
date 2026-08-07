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

TARGET_GROUP="$(id -gn "$TARGET_USER")"
STOW_SOURCE_ROOT="$TARGET_HOME/.local/share/setup-scripts"

sudo install -d -m 0755 \
    -o "$TARGET_USER" \
    -g "$TARGET_GROUP" \
    "$STOW_SOURCE_ROOT"

REPOS=(
    "$SCRIPT_DIR/dotfiles"
    "$SCRIPT_DIR/fishfiles"
)

for repo in "${REPOS[@]}"; do
    if [[ ! -d "$repo" ]]; then
        echo "Skipping '$repo' (directory not found)"
        continue
    fi

    source_name="$(basename "$repo")"
    user_source="$STOW_SOURCE_ROOT/$source_name"

    echo "Copying $repo into $user_source..."
    sudo install -d -m 0755 \
        -o "$TARGET_USER" \
        -g "$TARGET_GROUP" \
        "$user_source"
    sudo cp -a "$repo/." "$user_source/"
    sudo rm -f -- "$user_source/.git"
    sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$user_source"

    echo "Stowing $user_source into $TARGET_HOME..."
    (
        cd "$TARGET_HOME"
        sudo -H -u "$TARGET_USER" \
            env HOME="$TARGET_HOME" \
            stow --dir="$user_source" --target="$TARGET_HOME" .
    )
done

echo "Done."
