#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TARGET_USER:-}" ]] || [[ -z "${TARGET_HOME:-}" ]]; then
    echo "ERROR: TARGET_USER and TARGET_HOME must be set."
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PUBLIC_KEYS_DIR="$SCRIPT_DIR/../config/ssh/authorized_keys.d"
SSH_DIR="$TARGET_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
KEY_FILES=()
keys_found=0

if [[ ! -d "$PUBLIC_KEYS_DIR" ]]; then
    echo "ERROR: Public-key directory not found: $PUBLIC_KEYS_DIR"
    exit 1
fi

mapfile -d '' KEY_FILES < <(find "$PUBLIC_KEYS_DIR" -maxdepth 1 -type f -print0 | sort -z)
if (( ${#KEY_FILES[@]} == 0 )); then
    echo "ERROR: No public-key files found in $PUBLIC_KEYS_DIR."
    exit 1
fi

sudo -u "$TARGET_USER" mkdir -p "$SSH_DIR"
sudo -u "$TARGET_USER" chmod 700 "$SSH_DIR"

sudo -u "$TARGET_USER" touch "$AUTHORIZED_KEYS"
sudo -u "$TARGET_USER" chmod 600 "$AUTHORIZED_KEYS"

for key_file in "${KEY_FILES[@]}"; do
    while IFS= read -r public_key || [[ -n "$public_key" ]]; do
        if [[ -z "$public_key" ]] || [[ "$public_key" == \#* ]]; then
            continue
        fi

        keys_found=1
        if ! ssh-keygen -l -f <(printf '%s\n' "$public_key") >/dev/null; then
            echo "ERROR: Invalid SSH public key in $key_file."
            exit 1
        fi

        if sudo -u "$TARGET_USER" grep -qxF "$public_key" "$AUTHORIZED_KEYS"; then
            echo "SSH public key from $(basename -- "$key_file") is already authorized."
        else
            printf '%s\n' "$public_key" | sudo -u "$TARGET_USER" tee -a "$AUTHORIZED_KEYS" >/dev/null
            echo "SSH public key from $(basename -- "$key_file") added to $AUTHORIZED_KEYS."
        fi
    done < "$key_file"
done

if (( keys_found == 0 )); then
    echo "ERROR: No SSH public keys found in $PUBLIC_KEYS_DIR."
    exit 1
fi
