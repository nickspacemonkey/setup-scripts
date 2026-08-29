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
TEMP_RULE=""

is_kde_plasma_running() {
    local desktop="${XDG_CURRENT_DESKTOP:-}:${DESKTOP_SESSION:-}"

    desktop="${desktop,,}"
    if [[ "$desktop" == *kde* ]] || [[ "$desktop" == *plasma* ]]; then
        return 0
    fi

    command -v pgrep >/dev/null 2>&1 &&
        pgrep -u "$TARGET_USER" -x plasmashell >/dev/null 2>&1
}

if ! is_kde_plasma_running; then
    echo "WARNING: KDE Plasma is not running; skipping passwordless polkit configuration."
    exit 0
fi

cleanup() {
    if [[ -n "$TEMP_RULE" ]]; then
        rm -f -- "$TEMP_RULE"
    fi
}

trap cleanup EXIT

TEMP_RULE="$(mktemp)"
cat > "$TEMP_RULE" <<'EOF'
/* Allow members of the wheel group to execute any actions
 * without password authentication, similar to "sudo NOPASSWD:"
 */
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

install -d -m 0755 "$POLKIT_RULES_DIR"
install -m 0644 "$TEMP_RULE" "$POLKIT_RULE"

echo "Passwordless polkit authorization has been enabled for the wheel group."
