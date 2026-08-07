#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TARGET_USER:-}" ]]; then
    echo "ERROR: TARGET_USER must be set."
    exit 1
fi

SUDOERS_FILE="/etc/sudoers.d/${TARGET_USER}"
TEMP_SUDOERS=""

cleanup() {
    if [[ -n "$TEMP_SUDOERS" ]]; then
        rm -f -- "$TEMP_SUDOERS"
    fi
}

trap cleanup EXIT

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "ERROR: User '$TARGET_USER' does not exist."
    exit 1
fi

TEMP_SUDOERS="$(mktemp)"
printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$TARGET_USER" > "$TEMP_SUDOERS"

# Validate before modifying the live sudoers configuration
sudo visudo -cf "$TEMP_SUDOERS"

sudo install -m 0440 "$TEMP_SUDOERS" "$SUDOERS_FILE"

echo "Passwordless sudo has been enabled for user '${TARGET_USER}'."
