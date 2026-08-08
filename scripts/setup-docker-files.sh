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

echo "Docker helper scripts installed in $TARGET_DIR."
