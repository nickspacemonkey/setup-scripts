#!/usr/bin/env bash
set -euo pipefail

SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
PUBLIC_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMxO9oU80+Od4QpLsuoNERrbLrpq2T5BAoOT6vW2DrT hello@nickeu.com'

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

if grep -qxF "$PUBLIC_KEY" "$AUTHORIZED_KEYS"; then
    echo "SSH public key is already authorized."
else
    printf '%s\n' "$PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
    echo "SSH public key added to $AUTHORIZED_KEYS."
fi
