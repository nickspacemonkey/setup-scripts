#!/usr/bin/env bash
set -euo pipefail

USER="nick"
SUDOERS_FILE="/etc/sudoers.d/${USER}"

# Must be run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

cat > "$SUDOERS_FILE" <<EOF
${USER} ALL=(ALL:ALL) NOPASSWD: ALL
EOF

chmod 440 "$SUDOERS_FILE"

# Validate the sudoers configuration
visudo -cf "$SUDOERS_FILE"

echo "Passwordless sudo has been enabled for user '${USER}'."
