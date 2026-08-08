#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    echo "ERROR: This script must be run as root."
    exit 1
fi

TIMEZONE="Europe/London"
ZONEINFO_FILE="/usr/share/zoneinfo/$TIMEZONE"

if [[ ! -f "$ZONEINFO_FILE" ]]; then
    echo "ERROR: Timezone data not found: $ZONEINFO_FILE"
    exit 1
fi

if command -v timedatectl >/dev/null 2>&1 && timedatectl set-timezone "$TIMEZONE"; then
    :
else
    ln -sfn -- "$ZONEINFO_FILE" /etc/localtime
    if [[ -e /etc/timezone ]]; then
        printf '%s\n' "$TIMEZONE" > /etc/timezone
    fi
fi

if ! cmp -s -- "$ZONEINFO_FILE" /etc/localtime; then
    echo "ERROR: Failed to set timezone to $TIMEZONE."
    exit 1
fi

echo "Timezone set to $TIMEZONE."
