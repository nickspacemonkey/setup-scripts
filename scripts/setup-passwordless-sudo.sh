#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    echo "ERROR: This script must be run as root."
    exit 1
fi

if [[ -z "${TARGET_USER:-}" ]]; then
    echo "ERROR: TARGET_USER must be set."
    exit 1
fi

SUDOERS_FILE="/etc/sudoers.d/${TARGET_USER}"
TEMP_SUDOERS=""
VISUDO="$(command -v visudo 2>/dev/null || true)"

if [[ -z "$VISUDO" ]] && [[ -x /usr/sbin/visudo ]]; then
    VISUDO="/usr/sbin/visudo"
fi

if [[ -z "$VISUDO" ]]; then
    echo "ERROR: visudo was not found; install the sudo package and ensure its administration tools are available."
    exit 1
fi

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
"$VISUDO" -cf "$TEMP_SUDOERS"

install -m 0440 "$TEMP_SUDOERS" "$SUDOERS_FILE"

echo "Passwordless sudo has been enabled for user '${TARGET_USER}'."
