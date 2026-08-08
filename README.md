# Setup Scripts

Personal Linux bootstrap scripts for installing shell tools, configuring SSH and
sudo, and stowing Bash and Fish configuration from Git submodules.

## Prerequisites

- Bash
- `sudo` access
- Git, when cloning the repository normally
- One of the supported package managers: APT, DNF, YUM, Pacman, Zypper, or APK
- Account tools: `getent`, `id`, and either `useradd` or `adduser`
- Core utilities: `install`, `find`, and `readlink`
- `visudo`, normally provided with sudo

Minimal distributions and container images may require their account-management
and core utility packages to be installed before running the setup.

## Usage

Clone the repository and run the main setup script:

```bash
git clone https://github.com/nickspacemonkey/setup-scripts
cd setup-scripts
bash setup.sh
```

The script prompts for the user to configure, creates that account and its home
directory if necessary, and then performs these steps:

1. Installs sudo, tmux, Fish, and GNU Stow. On Debian, it also installs
   unattended-upgrades and applies the bundled
   `config/apt/50unattended-upgrades` configuration.
2. Initializes the `dotfiles` and `fishfiles` Git submodules at their pinned
   revisions.
3. Runs the remaining setup scripts.
4. Refreshes exact copies of the Bash and Fish configuration beneath
   `~/.local/share/setup-scripts` for the selected user.
5. Moves conflicting files into a timestamped directory beneath
   `~/.local/state/setup-scripts/backups`, private to the selected user.
6. Stows the configuration into the selected user's home directory.

Conflict handling includes files, leaf symlinks, and foreign symlinks in
intermediate directory components.

Run the setup as a normal user. Individual commands request `sudo` access when
needed.

## Submodules

Shell configuration is maintained in separate repositories:

- `dotfiles`: <https://github.com/nickspacemonkey/dotfiles>
- `fishfiles`: <https://github.com/nickspacemonkey/fishfiles>

`setup.sh` runs `git submodule update --init --recursive`. This checks out the
revisions pinned by this repository; it does not automatically select newer
upstream commits.

## Security-sensitive changes

The setup automatically:

- Adds the public key embedded in `scripts/setup-authorized-keys.sh` to
  `~/.ssh/authorized_keys` if it is not already present.
- Grants the selected user unrestricted passwordless sudo through a validated
  file in `/etc/sudoers.d`.

Review these scripts and confirm that the key and sudo policy are appropriate
before running the setup on a machine.
