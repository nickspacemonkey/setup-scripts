#!/usr/bin/env bash
set -uo pipefail

if (( EUID != 0 )); then
    echo "ERROR: This script must be run as root (for example: sudo bash setup.sh)."
    exit 1
fi

RUNNING_FROM_STDIN=0
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
else
    RUNNING_FROM_STDIN=1
    SCRIPT_DIR="$PWD"
fi
HELPER_DIR="$SCRIPT_DIR/scripts"
INSTALL_SCRIPT="$HELPER_DIR/install_tools.sh"
REPOSITORY_URL="https://github.com/nickspacemonkey/setup-scripts.git"
DEFAULT_CHECKOUT="/opt/setup-scripts"
DEFAULT_UID_MIN=1000
SETUP_SCRIPTS=(
    "$HELPER_DIR/setup-timezone.sh"
    "$HELPER_DIR/setup-authorized-keys.sh"
    "$HELPER_DIR/harden-ssh.sh"
    "$HELPER_DIR/setup-passwordless-sudo.sh"
    "$HELPER_DIR/stow-dotfiles.sh"
)
REQUESTED_USER=""
INSTALL_DOCKER=0
INSTALL_OLLAMA=0
INSTALL_CLAUDE=0
ALPINE_USER_CREATED=0

if (( $# > 0 )); then
    case "$1" in
        --user)
            if (( $# < 2 )); then
                echo "ERROR: --user requires a username."
                exit 1
            fi
            REQUESTED_USER="$2"
            shift 2
            ;;
        --user=*)
            REQUESTED_USER="${1#--user=}"
            shift
            ;;
        --*)
            echo "ERROR: Unknown option: $1"
            exit 1
            ;;
        *)
            # Retain compatibility with the original positional argument.
            REQUESTED_USER="$1"
            shift
            ;;
    esac
fi

while (( $# > 0 )); do
    case "$1" in
        docker)
            INSTALL_DOCKER=1
            shift
            ;;
        ollama)
            INSTALL_OLLAMA=1
            shift
            ;;
        claude)
            INSTALL_CLAUDE=1
            shift
            ;;
        *)
            echo "ERROR: Unexpected argument: $1"
            exit 1
            ;;
    esac
done

if (( INSTALL_DOCKER != 0 )); then
    SETUP_SCRIPTS=(
        "$HELPER_DIR/install-docker.sh"
        "$HELPER_DIR/setup-docker-files.sh"
        "${SETUP_SCRIPTS[@]}"
    )
fi

if (( INSTALL_OLLAMA != 0 )); then
    SETUP_SCRIPTS=(
        "$HELPER_DIR/install-ollama.sh"
        "${SETUP_SCRIPTS[@]}"
    )
fi

install_git() {
    command -v git >/dev/null 2>&1 && return

    echo "Git is required; installing it now..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y git
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y git
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm git
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install git
    elif command -v apk >/dev/null 2>&1; then
        apk add git
    else
        echo "ERROR: Cannot install Git: unsupported package manager."
        return 1
    fi
}

bootstrap_repository() {
    local checkout="${SETUP_SCRIPTS_CHECKOUT:-$DEFAULT_CHECKOUT}"
    local bootstrap_user checkout_origin

    bootstrap_user="$REQUESTED_USER"
    if [[ -z "$bootstrap_user" ]]; then
        read -r -p "Enter the username to configure: " bootstrap_user
    fi

    if [[ -z "$bootstrap_user" ]]; then
        echo "ERROR: A username is required."
        exit 1
    fi

    if [[ ! "$bootstrap_user" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
        echo "ERROR: '$bootstrap_user' is not a valid username."
        exit 1
    fi

    if ! install_git; then
        echo "ERROR: Failed to install Git."
        exit 1
    fi

    if [[ -e "$checkout" ]]; then
        if [[ ! -d "$checkout/.git" ]] || [[ ! -f "$checkout/setup.sh" ]]; then
            echo "ERROR: Bootstrap destination already exists and is not a setup-scripts checkout: $checkout"
            exit 1
        fi
        checkout_origin="$(git -C "$checkout" remote get-url origin 2>/dev/null || true)"
        if [[ "$checkout_origin" != "$REPOSITORY_URL" ]]; then
            echo "ERROR: Existing checkout has an unexpected origin: ${checkout_origin:-none}"
            exit 1
        fi

        echo "Updating existing setup-scripts checkout at $checkout..."
        if ! git -C "$checkout" pull --ff-only origin main; then
            echo "ERROR: Existing checkout could not be safely fast-forwarded."
            exit 1
        fi
    else
        echo "Cloning setup-scripts into $checkout..."
        mkdir -p -- "$(dirname -- "$checkout")"
        if ! git clone "$REPOSITORY_URL" "$checkout"; then
            echo "ERROR: Failed to clone $REPOSITORY_URL."
            exit 1
        fi
    fi

    EXEC_ARGS=("$bootstrap_user")
    if (( INSTALL_DOCKER != 0 )); then
        EXEC_ARGS+=("docker")
    fi
    if (( INSTALL_OLLAMA != 0 )); then
        EXEC_ARGS+=("ollama")
    fi
    if (( INSTALL_CLAUDE != 0 )); then
        EXEC_ARGS+=("claude")
    fi
    exec bash "$checkout/setup.sh" "${EXEC_ARGS[@]}"
}

# A downloaded copy of setup.sh can bootstrap the complete repository.
if (( RUNNING_FROM_STDIN != 0 )) || [[ ! -f "$INSTALL_SCRIPT" ]]; then
    bootstrap_repository "$@"
fi

TARGET_USER="$REQUESTED_USER"
if [[ -z "$TARGET_USER" ]]; then
    read -r -p "Enter the username to configure: " TARGET_USER
fi

if [[ -z "$TARGET_USER" ]]; then
    echo "ERROR: A username is required."
    exit 1
fi

if [[ ! "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
    echo "ERROR: '$TARGET_USER' is not a valid username."
    exit 1
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "Creating user '$TARGET_USER'..."
    if command -v useradd >/dev/null 2>&1; then
        useradd --create-home --shell /bin/bash -- "$TARGET_USER"
    elif command -v adduser >/dev/null 2>&1; then
        adduser -D -s /bin/bash "$TARGET_USER"
        ALPINE_USER_CREATED=1
    else
        echo "ERROR: Neither useradd nor adduser is available."
        exit 1
    fi
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "ERROR: Failed to create user '$TARGET_USER'."
    exit 1
fi

# Alpine's adduser -D leaves the account locked, which also prevents OpenSSH
# public-key authentication on Alpine's non-PAM OpenSSH server. Unlock only an
# account created by this run; SSH password authentication is disabled below.
if (( ALPINE_USER_CREATED != 0 )); then
    if ! passwd -u "$TARGET_USER"; then
        echo "ERROR: Failed to unlock Alpine user '$TARGET_USER' for SSH public-key authentication."
        exit 1
    fi
fi

UID_MIN="$(awk '$1 == "UID_MIN" { print $2; exit }' /etc/login.defs 2>/dev/null || true)"
UID_MIN="${UID_MIN:-$DEFAULT_UID_MIN}"
TARGET_UID="$(id -u "$TARGET_USER")"
if (( TARGET_UID == 0 || TARGET_UID < UID_MIN )); then
    echo "ERROR: '$TARGET_USER' is a root or system account (UID $TARGET_UID); a regular user is required."
    exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [[ -z "$TARGET_HOME" ]] || [[ ! -d "$TARGET_HOME" ]]; then
    echo "ERROR: Home directory for '$TARGET_USER' was not found."
    exit 1
fi

export TARGET_USER TARGET_HOME

# Run install_tools.sh first
if [[ -f "$INSTALL_SCRIPT" ]]; then
    echo "Running $INSTALL_SCRIPT..."
    INSTALL_TOOL_ARGS=()
    if (( INSTALL_OLLAMA != 0 )); then
        INSTALL_TOOL_ARGS+=("claude-ollama")
    elif (( INSTALL_CLAUDE != 0 )); then
        INSTALL_TOOL_ARGS+=("claude")
    fi
    if ! bash "$INSTALL_SCRIPT" "${INSTALL_TOOL_ARGS[@]}"; then
        echo "ERROR: $INSTALL_SCRIPT failed."
        exit 1
    fi
else
    echo "ERROR: $INSTALL_SCRIPT not found."
    exit 1
fi

# Initialize bundled configuration repositories after installing required tools
echo "Initializing Git submodules..."
if ! git -C "$SCRIPT_DIR" submodule update --init --recursive; then
    echo "ERROR: Failed to initialize Git submodules."
    exit 1
fi

# Run the remaining helper scripts in order
for script in "${SETUP_SCRIPTS[@]}"; do
    if [[ ! -f "$script" ]]; then
        echo "ERROR: $script not found."
        exit 1
    fi

    echo "Running $script..."
    if ! bash "$script"; then
        if [[ "$script" == "$HELPER_DIR/harden-ssh.sh" ]]; then
            echo "WARNING: $script failed; continuing without SSH hardening."
            continue
        fi
        echo "ERROR: $script failed."
        exit 1
    fi
done

echo "All scripts processed."
