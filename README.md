# Setup Scripts

Personal Linux bootstrap scripts for installing shell tools, Helix, bat, and
eza, configuring SSH and sudo, and stowing Bash and Fish configuration from
Git submodules.

## Prerequisites

- Bash, installed automatically by the one-line bootstrap when necessary
- `sudo` access
- Git, when cloning the repository normally
- One of the supported package managers: APT, DNF, Pacman, Zypper, or APK
- Account tools: `getent`, `id`, and either `useradd` or `adduser`
- Core utilities: `install`, `find`, and `readlink`
- `visudo`, normally provided with sudo
- systemd on DNF-based systems, for automatic-update and reboot timers
- OpenRC and BusyBox cron on Alpine, for automatic updates and reboots

Minimal distributions and container images may require their account-management
and core utility packages to be installed before running the setup.

## Usage

From a root shell, run the one-line installation for user `nick`:

```bash
wget -qO- https://raw.githubusercontent.com/nickspacemonkey/setup-scripts/main/bootstrap.sh | sh -s -- nick docker
```

From a root shell, the equivalent one-line installation with `curl` is:

```bash
curl -fsSL https://raw.githubusercontent.com/nickspacemonkey/setup-scripts/main/bootstrap.sh | sh -s -- nick docker
```

Or download it with `wget`:

```bash
wget https://raw.githubusercontent.com/nickspacemonkey/setup-scripts/main/setup.sh
sudo bash setup.sh
```

To skip the username prompt, pass the account with `--user`:

```bash
sudo bash setup.sh --user nick
```

Docker installation is optional. Pass `docker` as the second argument, after
the username, to install
and start Docker Engine with Buildx and Compose:

```bash
sudo bash setup.sh nick docker
```

To install Claude Code after the system tools and configure its Anthropic
environment settings without `OLLAMA_HOST`, pass `claude`:

```bash
sudo bash setup.sh nick claude
```

The `ollama` argument retains the full setup behavior and configures Claude Code
to use Ollama. It can be combined explicitly with `claude`; Ollama configuration
takes precedence and includes `OLLAMA_HOST`:

```bash
sudo bash setup.sh nick ollama claude
```

Set `SETUP_SCRIPTS_CHECKOUT` to use a different checkout location.

Alternatively, clone the repository and run the main setup script:

```bash
git clone https://github.com/nickspacemonkey/setup-scripts
cd setup-scripts
sudo bash setup.sh
```

The script prompts for the user to configure, creates that account and its home
directory if necessary, and then performs these steps:

1. Installs sudo, Git, timezone data, tmux, curl, wget, tar, ncdu, Fish, GNU
   Stow, Helix, bat, eza, and the OpenSSH server. APT systems also receive nala.
   Debian and Ubuntu use the `.deb` from the latest Helix release, while other
   supported package managers use their native Helix package. Debian and
   Ubuntu use eza's signed APT repository. On Debian and Ubuntu, setup also
   installs and enables
   unattended-upgrades using a bundled distribution-specific APT
   configuration. On DNF-based systems, it enables DNF4 or DNF5 automatic
   updates and a daily 06:00 reboot-if-required timer. Alpine installs updates
   daily at 02:00 using root cron jobs and reboots at 06:00 when an update
   replaced the running kernel. If a DNF distribution
   does not provide a requested tool in its enabled native repositories, setup
   attempts to enable CRB/PowerTools and EPEL, then retries. If eza remains
   unavailable, setup installs its official release binary on x86-64 or ARM64.
2. Initializes the Bash and Fish Git submodules under `config/` at their
   pinned revisions.
3. When the `docker` argument is supplied, installs and starts Docker Engine
   with Buildx and Compose using the host distribution's package format.
   Rocky Linux and AlmaLinux follow Docker's RHEL repository procedure,
   including removal of packages that conflict with Docker Engine. Setup also
   copies the bundled Docker Compose helper scripts into the selected user's
   `~/docker` directory and configures root's crontab to run
   `docker_cron.sh` daily at 04:00 unless a similar job already exists.
4. Sets the system timezone to `Europe/London`.
5. Adds the configured user's SSH public key, then disables SSH root login and
   all non-public-key authentication.
6. Runs the remaining setup scripts, stopping immediately if one fails.
7. Refreshes exact copies of the Bash and Fish configuration beneath
   `~/.local/share/setup-scripts` for the selected user.
8. Moves conflicting files into a timestamped directory beneath
   `~/.local/state/setup-scripts/backups`, private to the selected user.
9. Stows the configuration into the selected user's home directory.

Conflict handling includes files, leaf symlinks, and foreign symlinks in
intermediate directory components.

Run the setup as root, normally through `sudo`. The script exits before making
changes if it does not have root privileges.

## Submodules

Bundled configuration and helper scripts are maintained in separate repositories:

- `config/bash`: <https://github.com/nickspacemonkey/dotfiles>
- `config/docker`: <https://github.com/nickspacemonkey/docker-compose-scripts>
- `config/fish`: <https://github.com/nickspacemonkey/fishfiles>

`setup.sh` runs `git submodule update --init --recursive`. This checks out the
revisions pinned by this repository; it does not automatically select newer
upstream commits.

## Security-sensitive changes

The setup automatically:

- Validates and adds every public key in `config/ssh/authorized_keys.d` to
  `~/.ssh/authorized_keys` if it is not already present.
- Configures SSH to deny root login and require public-key authentication,
  then validates and reloads the SSH server configuration.
- Installs updates automatically and permits an unattended reboot at 06:00
  when APT or DNF reports that one is required, or when Alpine replaces the
  running kernel, even with users logged in.
- Grants the selected user unrestricted passwordless sudo through a validated
  file in `/etc/sudoers.d`.
- Runs the Docker maintenance helper as root every day at 04:00 when Docker
  installation is requested. The helper updates Compose projects and prunes
  unused Docker images, containers, networks, and volumes.

Review these scripts and confirm that the key and sudo policy are appropriate
before running the setup on a machine.
