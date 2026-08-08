#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    echo "ERROR: This script must be run as root."
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    echo "ERROR: Cannot detect the host distribution: /etc/os-release is missing."
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

DOCKER_PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)
RHEL_CONFLICTING_PACKAGES=(
    docker
    docker-client
    docker-client-latest
    docker-common
    docker-latest
    docker-latest-logrotate
    docker-logrotate
    docker-engine
    podman
    runc
)

install_docker_apt() {
    local docker_distribution="$ID"
    local codename architecture

    if [[ "$docker_distribution" != "debian" ]] && [[ "$docker_distribution" != "ubuntu" ]]; then
        echo "ERROR: Docker's APT repository does not support $docker_distribution directly."
        exit 1
    fi

    codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    if [[ -z "$codename" ]]; then
        echo "ERROR: Could not determine the distribution codename."
        exit 1
    fi

    apt-get update
    apt-get install -y ca-certificates curl
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/$docker_distribution/gpg" \
        -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    architecture="$(dpkg --print-architecture)"
    cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/$docker_distribution
Suites: $codename
Components: stable
Architectures: $architecture
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    apt-get update
    apt-get install -y "${DOCKER_PACKAGES[@]}"
}

install_docker_dnf() {
    local repository_distribution
    local repository_url
    local remove_conflicting_packages=0

    case "$ID" in
        fedora|centos)
            repository_distribution="$ID"
            ;;
        rhel)
            repository_distribution="rhel"
            remove_conflicting_packages=1
            ;;
        rocky|almalinux)
            repository_distribution="rhel"
            remove_conflicting_packages=1
            echo "NOTICE: Docker does not explicitly support $ID; following its RHEL installation procedure."
            ;;
        *)
            echo "ERROR: Docker does not provide a repository mapping for DNF distribution '$ID'."
            exit 1
            ;;
    esac

    if (( remove_conflicting_packages != 0 )); then
        dnf remove -y "${RHEL_CONFLICTING_PACKAGES[@]}"
    fi

    dnf install -y dnf-plugins-core
    repository_url="https://download.docker.com/linux/$repository_distribution/docker-ce.repo"

    # Replace an earlier CentOS mapping when rerunning setup on Rocky or AlmaLinux.
    rm -f -- /etc/yum.repos.d/docker-ce.repo
    if dnf config-manager --help 2>&1 | grep -q -- '--add-repo'; then
        dnf config-manager --add-repo "$repository_url"
    else
        dnf config-manager addrepo --from-repofile "$repository_url"
    fi

    dnf install -y "${DOCKER_PACKAGES[@]}"
}

start_docker() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable --now docker.service
    elif command -v rc-update >/dev/null 2>&1 && command -v rc-service >/dev/null 2>&1; then
        rc-update add docker default
        rc-service docker start
    else
        echo "ERROR: No supported service manager was found to start Docker."
        exit 1
    fi
}

if command -v apt-get >/dev/null 2>&1; then
    install_docker_apt
elif command -v dnf >/dev/null 2>&1; then
    install_docker_dnf
elif command -v pacman >/dev/null 2>&1; then
    pacman -S --needed --noconfirm docker docker-buildx docker-compose
elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install docker docker-compose
elif command -v apk >/dev/null 2>&1; then
    apk add docker docker-cli-buildx docker-cli-compose
else
    echo "ERROR: Unsupported package manager for Docker installation."
    exit 1
fi

start_docker

docker --version
docker compose version
echo "Docker Engine installation complete."
