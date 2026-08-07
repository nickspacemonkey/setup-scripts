#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TARGET_USER:-}" ]] || [[ -z "${TARGET_HOME:-}" ]]; then
    echo "ERROR: TARGET_USER and TARGET_HOME must be set."
    exit 1
fi

SSH_DIR="$TARGET_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
PUBLIC_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMxO9oU80+Od4QpLsuoNERrbLrpq2T5BAoOT6vW2DrT hello@nickeu.com'

sudo -u "$TARGET_USER" mkdir -p "$SSH_DIR"
sudo -u "$TARGET_USER" chmod 700 "$SSH_DIR"

sudo -u "$TARGET_USER" touch "$AUTHORIZED_KEYS"
sudo -u "$TARGET_USER" chmod 600 "$AUTHORIZED_KEYS"

if sudo -u "$TARGET_USER" grep -qxF "$PUBLIC_KEY" "$AUTHORIZED_KEYS"; then
    echo "SSH public key is already authorized."
else
    printf '%s\n' "$PUBLIC_KEY" | sudo -u "$TARGET_USER" tee -a "$AUTHORIZED_KEYS" >/dev/null
    echo "SSH public key added to $AUTHORIZED_KEYS."
fi
