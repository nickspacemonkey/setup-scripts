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
    install -d -m 0755 -o root -g root /run/sshd
}

ensure_ssh_host_keys() {
    local host_key

    if ! command -v ssh-keygen >/dev/null 2>&1; then
        echo "ERROR: ssh-keygen is required to generate SSH host keys."
        return 1
    fi

    if ! ssh-keygen -A; then
        echo "ERROR: Failed to generate missing SSH host keys."
        return 1
    fi

    for host_key in /etc/ssh/ssh_host_*_key; do
        if [[ -s "$host_key" ]]; then
            return 0
        fi
    done

    echo "ERROR: No SSH host keys were generated."
    return 1
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

if ! test -s "$AUTHORIZED_KEYS"; then
    echo "ERROR: Refusing to disable SSH passwords before $AUTHORIZED_KEYS contains a key."
    exit 1
fi

if [[ ! -f "$SSHD_CONFIG" ]]; then
    echo "ERROR: OpenSSH server configuration not found: $SSHD_CONFIG"
    exit 1
fi

ensure_ssh_host_keys

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

install -d -m 0755 "$SSHD_CONFIG_DIR"
ensure_sshd_runtime_dir

if test -f "$HARDENING_CONFIG"; then
    BACKUP_CONFIG="$(mktemp)"
    cat "$HARDENING_CONFIG" > "$BACKUP_CONFIG"
fi

install -m 0644 "$TEMP_CONFIG" "$HARDENING_CONFIG"

restore_previous_config() {
    if [[ -n "$BACKUP_CONFIG" ]]; then
        install -m 0644 "$BACKUP_CONFIG" "$HARDENING_CONFIG"
    else
        rm -f -- "$HARDENING_CONFIG"
    fi
}

if ! sshd -t ||
   ! EFFECTIVE_CONFIG="$(sshd -T -C "user=$TARGET_USER,host=localhost,addr=127.0.0.1")"; then
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
            if systemctl cat "$unit" >/dev/null 2>&1; then
                systemctl enable "$unit" && systemctl restart "$unit"
                return
            fi
        done
    elif command -v rc-service >/dev/null 2>&1; then
        rc-update add sshd default && rc-service sshd restart
        return
    elif command -v service >/dev/null 2>&1; then
        if service ssh restart; then
            return
        fi
        service sshd restart
        return
    fi

    return 1
}

if ! activate_ssh_service; then
    restore_previous_config
    ensure_sshd_runtime_dir
    if sshd -t; then
        activate_ssh_service || true
    fi
    echo "ERROR: Could not activate SSH; the previous configuration was restored."
    exit 1
fi

echo "SSH now denies root login and accepts public-key authentication only."
