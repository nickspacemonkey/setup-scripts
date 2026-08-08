#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TARGET_USER:-}" ]] || [[ -z "${TARGET_HOME:-}" ]]; then
    echo "ERROR: TARGET_USER and TARGET_HOME must be set."
    exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
HARDENING_CONFIG="$SSHD_CONFIG_DIR/00-setup-scripts-hardening.conf"
AUTHORIZED_KEYS="$TARGET_HOME/.ssh/authorized_keys"
TEMP_CONFIG=""
BACKUP_CONFIG=""
EFFECTIVE_CONFIG=""

ensure_sshd_runtime_dir() {
    sudo install -d -m 0755 -o root -g root /run/sshd
}

cleanup() {
    if [[ -n "$TEMP_CONFIG" ]]; then
        rm -f -- "$TEMP_CONFIG"
    fi
    if [[ -n "$BACKUP_CONFIG" ]]; then
        rm -f -- "$BACKUP_CONFIG"
    fi
}

trap cleanup EXIT

if ! sudo test -s "$AUTHORIZED_KEYS"; then
    echo "ERROR: Refusing to disable SSH passwords before $AUTHORIZED_KEYS contains a key."
    exit 1
fi

if [[ ! -f "$SSHD_CONFIG" ]]; then
    echo "ERROR: OpenSSH server configuration not found: $SSHD_CONFIG"
    exit 1
fi

if ! grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf([[:space:]]|$)' "$SSHD_CONFIG"; then
    echo "ERROR: $SSHD_CONFIG does not include $SSHD_CONFIG_DIR/*.conf."
    exit 1
fi

TEMP_CONFIG="$(mktemp)"
cat > "$TEMP_CONFIG" <<'EOF'
# Managed by setup-scripts/scripts/harden-ssh.sh
PermitRootLogin no
PubkeyAuthentication yes
AuthenticationMethods publickey
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
EOF

sudo install -d -m 0755 "$SSHD_CONFIG_DIR"
ensure_sshd_runtime_dir

if sudo test -f "$HARDENING_CONFIG"; then
    BACKUP_CONFIG="$(mktemp)"
    sudo cat "$HARDENING_CONFIG" > "$BACKUP_CONFIG"
fi

sudo install -m 0644 "$TEMP_CONFIG" "$HARDENING_CONFIG"

restore_previous_config() {
    if [[ -n "$BACKUP_CONFIG" ]]; then
        sudo install -m 0644 "$BACKUP_CONFIG" "$HARDENING_CONFIG"
    else
        sudo rm -f -- "$HARDENING_CONFIG"
    fi
}

if ! sudo sshd -t ||
   ! EFFECTIVE_CONFIG="$(sudo sshd -T -C "user=$TARGET_USER,host=localhost,addr=127.0.0.1")"; then
    restore_previous_config
    echo "ERROR: SSH configuration validation failed; the previous config was restored."
    exit 1
fi

REQUIRED_SETTINGS=(
    "permitrootlogin no"
    "pubkeyauthentication yes"
    "authenticationmethods publickey"
    "passwordauthentication no"
    "kbdinteractiveauthentication no"
)

for setting in "${REQUIRED_SETTINGS[@]}"; do
    if ! grep -Fqx "$setting" <<< "$EFFECTIVE_CONFIG"; then
        restore_previous_config
        echo "ERROR: Effective SSH setting is not '$setting'; the previous config was restored."
        exit 1
    fi
done

activate_ssh_service() {
    ensure_sshd_runtime_dir

    if command -v systemctl >/dev/null 2>&1; then
        local unit
        for unit in ssh.service sshd.service; do
            if sudo systemctl cat "$unit" >/dev/null 2>&1; then
                sudo systemctl enable "$unit" && sudo systemctl restart "$unit"
                return
            fi
        done
    elif command -v rc-service >/dev/null 2>&1; then
        sudo rc-update add sshd default && sudo rc-service sshd restart
        return
    elif command -v service >/dev/null 2>&1; then
        if sudo service ssh restart; then
            return
        fi
        sudo service sshd restart
        return
    fi

    return 1
}

if ! activate_ssh_service; then
    restore_previous_config
    ensure_sshd_runtime_dir
    if sudo sshd -t; then
        activate_ssh_service || true
    fi
    echo "ERROR: Could not activate SSH; the previous configuration was restored."
    exit 1
fi

echo "SSH now denies root login and accepts public-key authentication only."
