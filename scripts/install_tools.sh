#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    echo "ERROR: This script must be run as root."
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APT_CONFIG_DIR="$SCRIPT_DIR/../config/apt"
AUTO_UPGRADES_CONFIG="$SCRIPT_DIR/../config/apt/20auto-upgrades"
DNF_AUTOMATIC_CONFIG="$SCRIPT_DIR/../config/dnf/automatic.conf"
REBOOT_CHECK_SCRIPT="$SCRIPT_DIR/reboot-if-needed.sh"
SYSTEMD_CONFIG_DIR="$SCRIPT_DIR/../config/systemd"

get_distro_id() {
    [[ -r /etc/os-release ]] || return

    (. /etc/os-release && printf '%s' "${ID:-}")
}

configure_dnf_automatic() {
    local automatic_timer=""
    local unit

    if [[ ! -f "$DNF_AUTOMATIC_CONFIG" ]] ||
       [[ ! -f "$REBOOT_CHECK_SCRIPT" ]] ||
       [[ ! -f "$SYSTEMD_CONFIG_DIR/setup-scripts-reboot-if-needed.service" ]] ||
       [[ ! -f "$SYSTEMD_CONFIG_DIR/setup-scripts-reboot-if-needed.timer" ]]; then
        echo "ERROR: Bundled DNF automatic-update configuration is incomplete."
        exit 1
    fi

    install -d -m 0755 /etc/dnf /usr/local/sbin
    install -m 0644 "$DNF_AUTOMATIC_CONFIG" /etc/dnf/automatic.conf
    install -m 0755 "$REBOOT_CHECK_SCRIPT" /usr/local/sbin/setup-scripts-reboot-if-needed
    install -m 0644 "$SYSTEMD_CONFIG_DIR/setup-scripts-reboot-if-needed.service" /etc/systemd/system/
    install -m 0644 "$SYSTEMD_CONFIG_DIR/setup-scripts-reboot-if-needed.timer" /etc/systemd/system/

    systemctl daemon-reload

    if command -v dnf5 >/dev/null 2>&1 &&
       dnf5 automatic --help >/dev/null 2>&1 &&
       systemctl cat dnf5-automatic.timer >/dev/null 2>&1; then
        automatic_timer="dnf5-automatic.timer"
    elif systemctl cat dnf-automatic-install.timer >/dev/null 2>&1; then
        automatic_timer="dnf-automatic-install.timer"
    elif systemctl cat dnf-automatic.timer >/dev/null 2>&1; then
        automatic_timer="dnf-automatic.timer"
    else
        echo "ERROR: No supported DNF automatic-update timer was found."
        exit 1
    fi

    for unit in \
        dnf5-automatic.timer \
        dnf-automatic.timer \
        dnf-automatic-install.timer \
        dnf-automatic-download.timer \
        dnf-automatic-notifyonly.timer; do
        if [[ "$unit" != "$automatic_timer" ]]; then
            systemctl disable --now "$unit" >/dev/null 2>&1 || true
        fi
    done

    systemctl enable --now "$automatic_timer"
    systemctl enable --now setup-scripts-reboot-if-needed.timer
}

install_packages() {
    local distro_id unattended_upgrades_config

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh-server

        distro_id="$(get_distro_id)"
        if [[ "$distro_id" == "debian" ]] || [[ "$distro_id" == "ubuntu" ]]; then
            unattended_upgrades_config="$APT_CONFIG_DIR/$distro_id/50unattended-upgrades"
            if [[ ! -f "$unattended_upgrades_config" ]] || [[ ! -f "$AUTO_UPGRADES_CONFIG" ]]; then
                echo "ERROR: Bundled unattended-upgrades configuration is incomplete."
                exit 1
            fi

            apt-get install -y unattended-upgrades
            install -m 0644 \
                "$AUTO_UPGRADES_CONFIG" \
                /etc/apt/apt.conf.d/20auto-upgrades
            install -m 0644 \
                "$unattended_upgrades_config" \
                /etc/apt/apt.conf.d/50unattended-upgrades
        fi

    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh-server \
            dnf-automatic \
            dnf-plugins-core

        configure_dnf_automatic

    elif command -v yum >/dev/null 2>&1; then
        yum install -y \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh-server \
            dnf-automatic \
            dnf-plugins-core

        configure_dnf_automatic

    elif command -v pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh

    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh-server

    elif command -v apk >/dev/null 2>&1; then
        apk add \
            sudo \
            git \
            tmux \
            fish \
            stow \
            openssh-server

    else
        echo "ERROR: Unsupported package manager."
        exit 1
    fi
}

echo "Installing sudo, Git, tmux, fish, stow, and OpenSSH server..."
install_packages

echo
echo "Installed versions:"
echo "-------------------"
command -v sudo >/dev/null && sudo --version | sed -n '1p'
command -v git >/dev/null && git --version
command -v tmux >/dev/null && tmux -V
command -v fish >/dev/null && fish --version
command -v stow >/dev/null && stow --version | head -n1
command -v sshd >/dev/null && sshd -V 2>&1 | sed -n '1p'

echo
echo "Installation complete."
