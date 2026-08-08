#!/usr/bin/env bash
set -uo pipefail

check_reboot_required() {
    if command -v dnf5 >/dev/null 2>&1 && dnf5 needs-restarting --help >/dev/null 2>&1; then
        dnf5 needs-restarting --reboothint
    elif command -v dnf >/dev/null 2>&1 && dnf needs-restarting --help >/dev/null 2>&1; then
        dnf needs-restarting --reboothint
    else
        echo "ERROR: No supported DNF needs-restarting command was found."
        return 2
    fi
}

check_reboot_required
status=$?

case "$status" in
    0)
        echo "DNF reports that no reboot is required."
        ;;
    1)
        echo "DNF reports that a reboot is required; rebooting now."
        systemctl reboot
        ;;
    *)
        echo "ERROR: DNF reboot check failed with status $status."
        exit "$status"
        ;;
esac
