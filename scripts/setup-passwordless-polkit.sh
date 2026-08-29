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

POLKIT_RULES_DIR="/etc/polkit-1/rules.d"
POLKIT_RULE="$POLKIT_RULES_DIR/49-nopasswd_global.rules"
OS_RELEASE="/etc/os-release"
TEMP_RULE=""
ADMIN_GROUP="wheel"

is_supported_desktop_running() {
    local desktop="${XDG_CURRENT_DESKTOP:-}:${DESKTOP_SESSION:-}"

    desktop="${desktop,,}"
    if [[ "$desktop" == *kde* ]] ||
       [[ "$desktop" == *plasma* ]] ||
       [[ "$desktop" == *gnome* ]]; then
        return 0
    fi

    if ! command -v pgrep >/dev/null 2>&1; then
        return 1
    fi

    pgrep -u "$TARGET_USER" -x plasmashell >/dev/null 2>&1 ||
        pgrep -u "$TARGET_USER" -x gnome-shell >/dev/null 2>&1
}

is_debian_based() {
    local distro

    if [[ ! -r "$OS_RELEASE" ]]; then
        return 1
    fi

    distro="$(
        # shellcheck disable=SC1090
        source "$OS_RELEASE"
        printf '%s %s' "${ID:-}" "${ID_LIKE:-}"
    )"
    distro="${distro,,}"

    [[ " $distro " == *" debian "* ]] || [[ " $distro " == *" ubuntu "* ]]
}

if ! is_supported_desktop_running; then
    echo "WARNING: KDE Plasma or GNOME is not running; skipping passwordless polkit configuration."
    exit 0
fi

if is_debian_based; then
    ADMIN_GROUP="sudo"
fi

cleanup() {
    if [[ -n "$TEMP_RULE" ]]; then
        rm -f -- "$TEMP_RULE"
    fi
}

trap cleanup EXIT

TEMP_RULE="$(mktemp)"
cat > "$TEMP_RULE" <<EOF
/* Allow members of the $ADMIN_GROUP group to execute any actions
 * without password authentication, similar to "sudo NOPASSWD:"
 */
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("$ADMIN_GROUP")) {
        return polkit.Result.YES;
    }
});
EOF

install -d -m 0755 "$POLKIT_RULES_DIR"
install -m 0644 "$TEMP_RULE" "$POLKIT_RULE"

echo "Passwordless polkit authorization has been enabled for the $ADMIN_GROUP group."
