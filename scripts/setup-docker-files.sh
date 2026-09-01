#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    echo "ERROR: This script must be run as root."
    exit 1
fi

if [[ -z "${TARGET_USER:-}" ]] || [[ -z "${TARGET_HOME:-}" ]]; then
    echo "ERROR: TARGET_USER and TARGET_HOME must be set."
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/../config/docker"
TARGET_DIR="$TARGET_HOME/docker"
TARGET_GROUP="$(id -gn "$TARGET_USER")"
EXPECTED_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TEMP_FILE=""
CRON_MARKER="# setup-scripts Docker maintenance"

cleanup() {
    if [[ -n "$TEMP_FILE" ]]; then
        rm -f -- "$TEMP_FILE"
    fi
}

trap cleanup EXIT

if [[ -z "$EXPECTED_HOME" ]] || [[ "$TARGET_HOME" != "$EXPECTED_HOME" ]]; then
    echo "ERROR: TARGET_HOME does not match the home directory for '$TARGET_USER'."
    exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "ERROR: Docker helper submodule not found: $SOURCE_DIR"
    exit 1
fi

install_cron() {
    if command -v crontab >/dev/null 2>&1; then
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y cron
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y cronie
    elif command -v pacman >/dev/null 2>&1; then
        pacman -S --needed --noconfirm cronie
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install cron
    elif command -v apk >/dev/null 2>&1; then
        apk add busybox busybox-openrc
    else
        echo "ERROR: Cannot install cron: unsupported package manager."
        return 1
    fi
}

start_cron() {
    local unit

    if command -v systemctl >/dev/null 2>&1; then
        for unit in cron.service crond.service; do
            if systemctl cat "$unit" >/dev/null 2>&1; then
                systemctl enable --now "$unit"
                return
            fi
        done
    elif command -v rc-service >/dev/null 2>&1; then
        rc-update add crond default
        rc-service crond start
        return
    fi

    echo "ERROR: No supported cron service was found."
    return 1
}

configure_root_crontab() {
    local cron_command

    TEMP_FILE="$(mktemp)"
    crontab -l > "$TEMP_FILE" 2>/dev/null || true

    if awk '
        /^[[:space:]]*#/ { next }
        /docker_cron\.sh([[:space:]]|$)/ { found = 1 }
        END { exit !found }
    ' "$TEMP_FILE"; then
        echo "A root cron job for docker_cron.sh already exists; leaving it unchanged."
        rm -f -- "$TEMP_FILE"
        TEMP_FILE=""
        return
    fi

    printf -v cron_command '%q' "$TARGET_DIR/docker_cron.sh"
    printf '%s\n0 4 * * * bash %s >/dev/null 2>&1\n' \
        "$CRON_MARKER" \
        "$cron_command" \
        >> "$TEMP_FILE"
    crontab "$TEMP_FILE"
    rm -f -- "$TEMP_FILE"
    TEMP_FILE=""
}

install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$TARGET_DIR"

for source_file in "$SOURCE_DIR"/*; do
    [[ -f "$source_file" ]] || continue
    target_file="$TARGET_DIR/$(basename -- "$source_file")"

    if [[ "$(basename -- "$source_file")" == "docker_cron.sh" ]]; then
        TEMP_FILE="$(mktemp)"
        sed "s#/home/nick/docker#$TARGET_DIR#g" "$source_file" > "$TEMP_FILE"
        install -m 0755 "$TEMP_FILE" "$target_file"
        rm -f -- "$TEMP_FILE"
        TEMP_FILE=""
    elif [[ -x "$source_file" ]]; then
        install -m 0755 "$source_file" "$target_file"
    else
        install -m 0644 "$source_file" "$target_file"
    fi

    chown "$TARGET_USER:$TARGET_GROUP" "$target_file"
done

install_cron
start_cron
configure_root_crontab

echo "Docker helper scripts installed in $TARGET_DIR."
echo "Root cron will run docker_cron.sh daily at 04:00."
