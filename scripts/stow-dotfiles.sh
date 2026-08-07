#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

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
BACKUP_ROOT="$TARGET_HOME/.local/state/setup-scripts/backups/$(date +%Y%m%d-%H%M%S)-$$"
backup_created=0

backup_target() {
    local target_path="$1"
    local source_name="$2"
    local relative_path="$3"
    local backup_path="$BACKUP_ROOT/$source_name/$relative_path"

    sudo install -d -m 0700 \
        -o "$TARGET_USER" \
        -g "$TARGET_GROUP" \
        "$(dirname "$backup_path")"
    sudo mv -- "$target_path" "$backup_path"
    sudo chown -h "$TARGET_USER:$TARGET_GROUP" "$backup_path"
    backup_created=1
    echo "Backed up $target_path to $backup_path"
}

backup_conflicts() {
    local source_root="$1"
    local source_name="$2"
    local source_path relative_path target_path
    local source_real target_real
    local parent_path source_parent target_parent source_parent_real target_parent_real
    local -a parent_paths

    while IFS= read -r -d '' source_path; do
        relative_path="${source_path#"$source_root"/}"
        target_path="$TARGET_HOME/$relative_path"

        parent_paths=()
        parent_path="$(dirname -- "$relative_path")"
        while [[ "$parent_path" != "." ]] && [[ "$parent_path" != "/" ]]; do
            parent_paths=("$parent_path" "${parent_paths[@]}")
            parent_path="$(dirname -- "$parent_path")"
        done

        for parent_path in "${parent_paths[@]}"; do
            source_parent="$source_root/$parent_path"
            target_parent="$TARGET_HOME/$parent_path"

            if [[ -L "$target_parent" ]]; then
                source_parent_real="$(readlink -f -- "$source_parent" || true)"
                target_parent_real="$(readlink -f -- "$target_parent" || true)"
                if [[ -n "$source_parent_real" ]] && [[ "$target_parent_real" == "$source_parent_real" ]]; then
                    continue
                fi

                backup_target "$target_parent" "$source_name" "$parent_path"
                break
            fi

            if [[ -e "$target_parent" ]] && [[ ! -d "$target_parent" ]]; then
                backup_target "$target_parent" "$source_name" "$parent_path"
                break
            fi
        done

        if [[ ! -e "$target_path" ]] && [[ ! -L "$target_path" ]]; then
            continue
        fi

        source_real="$(readlink -f -- "$source_path" || true)"
        target_real="$(readlink -f -- "$target_path" || true)"
        if [[ -n "$source_real" ]] && [[ "$target_real" == "$source_real" ]]; then
            continue
        fi

        backup_target "$target_path" "$source_name" "$relative_path"
    done < <(find "$source_root" \( -type f -o -type l \) -print0)
}

sudo install -d -m 0755 \
    -o "$TARGET_USER" \
    -g "$TARGET_GROUP" \
    "$STOW_SOURCE_ROOT"

REPOS=(
    "$REPO_ROOT/dotfiles"
    "$REPO_ROOT/fishfiles"
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

    if [[ -n "$(sudo find "$user_source" -mindepth 1 -print -quit)" ]]; then
        echo "Removing links from the previous $source_name mirror..."
        (
            cd "$TARGET_HOME"
            sudo -H -u "$TARGET_USER" \
                env HOME="$TARGET_HOME" \
                stow --delete --dir="$user_source" --target="$TARGET_HOME" .
        )
    fi

    sudo find "$user_source" -mindepth 1 -depth -delete
    sudo cp -a "$repo/." "$user_source/"
    sudo rm -f -- "$user_source/.git"
    sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$user_source"

    backup_conflicts "$user_source" "$source_name"

    echo "Stowing $user_source into $TARGET_HOME..."
    (
        cd "$TARGET_HOME"
        sudo -H -u "$TARGET_USER" \
            env HOME="$TARGET_HOME" \
            stow --dir="$user_source" --target="$TARGET_HOME" .
    )
done

if (( backup_created != 0 )); then
    echo "Existing files were backed up under $BACKUP_ROOT."
fi

echo "Done."
