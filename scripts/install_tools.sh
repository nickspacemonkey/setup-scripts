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

get_distro_version_id() {
    [[ -r /etc/os-release ]] || return

    (. /etc/os-release && printf '%s' "${VERSION_ID:-}")
}

install_helix_deb() {
    local architecture asset_url download_dir package_file

    architecture="$(dpkg --print-architecture)"
    asset_url="$(
        curl -fsSL https://api.github.com/repos/helix-editor/helix/releases/latest |
            sed -n "s#.*\"browser_download_url\": \"\([^\"]*_${architecture}\\.deb\)\".*#\1#p" |
            head -n1
    )"

    if [[ -z "$asset_url" ]]; then
        echo "ERROR: No Helix Debian package is available for architecture '$architecture'."
        return 1
    fi

    download_dir="$(mktemp -d)"
    package_file="$download_dir/helix.deb"
    if ! curl -fsSL "$asset_url" -o "$package_file" ||
       ! apt-get install -y "$package_file"; then
        rm -rf -- "$download_dir"
        return 1
    fi
    rm -rf -- "$download_dir"
}

remove_helix_ppa() {
    local source_file

    for source_file in /etc/apt/sources.list.d/*; do
        [[ -f "$source_file" ]] || continue
        if grep -q 'maveonair/helix-editor\|maveonair.*helix-editor' "$source_file"; then
            echo "Removing unsupported Helix PPA source: $source_file"
            rm -f -- "$source_file"
        fi
    done
}

configure_eza_apt_repository() {
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc |
        gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg
    printf '%s\n' \
        'deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main' \
        > /etc/apt/sources.list.d/gierens.list
    chmod 0644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
}

install_eza_binary() {
    local architecture download_dir archive

    case "$(uname -m)" in
        x86_64)
            architecture="x86_64"
            ;;
        aarch64 | arm64)
            architecture="aarch64"
            ;;
        *)
            echo "ERROR: No eza binary installation is configured for architecture '$(uname -m)'."
            return 1
            ;;
    esac

    download_dir="$(mktemp -d)"
    archive="$download_dir/eza.tar.gz"
    if ! curl -fsSL \
        "https://github.com/eza-community/eza/releases/latest/download/eza_${architecture}-unknown-linux-gnu.tar.gz" \
        -o "$archive" ||
       ! tar -xzf "$archive" -C "$download_dir" ||
       [[ ! -f "$download_dir/eza" ]]; then
        rm -rf -- "$download_dir"
        echo "ERROR: Failed to download and extract eza."
        return 1
    fi

    install -m 0755 "$download_dir/eza" /usr/local/bin/eza
    rm -rf -- "$download_dir"
}

ensure_bat_command() {
    if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
        install -d -m 0755 /usr/local/bin
        ln -s "$(command -v batcat)" /usr/local/bin/bat
    fi
}

enable_dnf_extra_repositories() {
    local major_version

    echo "A requested tool was not found in the enabled repositories; trying EPEL..."
    if ! dnf install -y dnf-plugins-core epel-release; then
        echo "ERROR: This DNF distribution does not provide epel-release automatically."
        return 1
    fi

    if command -v crb >/dev/null 2>&1; then
        crb enable
        return
    fi

    major_version="$(get_distro_version_id)"
    major_version="${major_version%%.*}"
    if [[ "$major_version" == "8" ]]; then
        dnf config-manager --set-enabled powertools
    else
        dnf config-manager --set-enabled crb
    fi
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
        distro_id="$(get_distro_id)"
        remove_helix_ppa
        apt-get update
        apt-get install -y ca-certificates curl gpg
        configure_eza_apt_repository
        apt-get update

        apt-get install -y \
            sudo \
            git \
            tzdata \
            tmux \
            nala \
            wget \
            ncdu \
            fish \
            stow \
            bat \
            eza \
            openssh-server

        ensure_bat_command

        if [[ "$distro_id" == "ubuntu" ]] || [[ "$distro_id" == "debian" ]]; then
            install_helix_deb
        else
            echo "ERROR: Helix installation is not configured for APT distribution '$distro_id'."
            exit 1
        fi

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
            tzdata \
            tmux \
            curl \
            wget \
            openssh-server \
            dnf-automatic \
            dnf-plugins-core

        if ! dnf install -y fish stow helix bat ncdu; then
            enable_dnf_extra_repositories
            dnf install -y fish stow helix bat ncdu
        fi

        if ! dnf install -y eza; then
            echo "eza is not available from enabled DNF repositories; installing its release binary..."
            install_eza_binary
        fi

        configure_dnf_automatic

    elif command -v yum >/dev/null 2>&1; then
        yum install -y \
            sudo \
            git \
            tzdata \
            tmux \
            curl \
            wget \
            ncdu \
            fish \
            stow \
            bat \
            eza \
            openssh-server \
            dnf-automatic \
            dnf-plugins-core \
            helix

        configure_dnf_automatic

    elif command -v pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm \
            sudo \
            git \
            tzdata \
            tmux \
            curl \
            wget \
            ncdu \
            fish \
            stow \
            bat \
            eza \
            openssh \
            helix

    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install \
            sudo \
            git \
            timezone \
            tmux \
            curl \
            wget \
            ncdu \
            fish \
            stow \
            bat \
            eza \
            openssh-server \
            helix

    elif command -v apk >/dev/null 2>&1; then
        apk add \
            sudo \
            git \
            tzdata \
            tmux \
            curl \
            wget \
            ncdu \
            fish \
            stow \
            bat \
            eza \
            openssh-server \
            helix

    else
        echo "ERROR: Unsupported package manager."
        exit 1
    fi
}

echo "Installing sudo, Git, timezone data, tmux, curl, wget, ncdu, fish, stow, Helix, bat, eza, and OpenSSH server (plus nala on APT systems)..."
install_packages

echo
echo "Installed versions:"
echo "-------------------"
command -v sudo >/dev/null && sudo --version | sed -n '1p'
command -v git >/dev/null && git --version
command -v tmux >/dev/null && tmux -V
command -v nala >/dev/null && nala --version | sed -n '1p'
command -v curl >/dev/null && curl --version | sed -n '1p'
command -v wget >/dev/null && wget --version | sed -n '1p'
command -v ncdu >/dev/null && ncdu --version | sed -n '1p'
command -v fish >/dev/null && fish --version
command -v stow >/dev/null && stow --version | head -n1
command -v bat >/dev/null && bat --version
command -v eza >/dev/null && eza --version | sed -n '1p'
if command -v hx >/dev/null 2>&1; then
    hx --version | sed -n '1p'
elif command -v helix >/dev/null 2>&1; then
    helix --version | sed -n '1p'
fi
command -v sshd >/dev/null && sshd -V 2>&1 | sed -n '1p'

echo
echo "Installation complete."
