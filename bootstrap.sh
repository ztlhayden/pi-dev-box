#!/usr/bin/env bash
# bootstrap.sh: idempotent setup for the Pi dev box. Safe to re-run.
set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

# chezmoi expands this to https://github.com/<user>/<repo>.git
DOTFILES_REPO="${DOTFILES_REPO:-ztlhayden/pi-dev-box}"

# Read-only checks. Changes nothing; stops early if this isn't the machine we expect.
preflight() {
  log "Preflight checks"

  [[ $EUID -ne 0 ]] || die "run as your normal user, not root (sudo is used where needed)"

  local arch
  arch="$(dpkg --print-architecture)"
  [[ $arch == arm64 ]] || die "expected arm64, found $arch"

  # shellcheck disable=SC1091
  . /etc/os-release
  [[ $ID == ubuntu && $VERSION_ID == 26.04 ]] \
    || warn "written for Ubuntu 26.04, found $PRETTY_NAME"

  local root_dev
  root_dev="$(findmnt -no SOURCE /)"
  case $root_dev in
    /dev/nvme*)   log "root is on NVMe ($root_dev)" ;;
    /dev/mmcblk*) warn "root is on the SD card ($root_dev), not the NVMe" ;;
    *)            warn "root is on $root_dev" ;;
  esac
}

# build-essential is needed on arm64: npm packages without a prebuilt binary compile on install.
APT_PACKAGES=(git curl ca-certificates build-essential tmux unzip jq htop)

base_packages() {
  local missing=() pkg
  for pkg in "${APT_PACKAGES[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done

  if ((${#missing[@]} == 0)); then
    log "Base packages already installed"
    return
  fi

  log "Installing: ${missing[*]}"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
}

# gh from GitHub's own apt repo; Ubuntu's copy is frozen at the release version.
github_cli() {
  if has gh; then
    log "gh already installed"
    return
  fi

  log "Installing GitHub CLI"
  local keyring=/etc/apt/keyrings/githubcli-archive-keyring.gpg tmp
  tmp="$(mktemp)"
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$tmp"
  sudo install -D -m 644 "$tmp" "$keyring"
  rm -f "$tmp"

  echo "deb [arch=arm64 signed-by=$keyring] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gh
}

# 1Password has no Ubuntu package, so their apt repo is the only apt route.
onepassword_cli() {
  if has op; then
    log "op already installed"
    return
  fi

  log "Installing 1Password CLI"
  has gpg || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gpg

  local keyring=/usr/share/keyrings/1password-archive-keyring.gpg
  local debsig_id=AC2D62742012EA22 tmp
  tmp="$(mktemp)"
  curl -fsSL https://downloads.1password.com/linux/keys/1password.asc -o "$tmp"
  sudo gpg --dearmor --yes --output "$keyring" "$tmp"

  echo "deb [arch=arm64 signed-by=$keyring] https://downloads.1password.com/linux/debian/arm64 stable main" \
    | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null

  # Package-signature policy from 1Password's install docs; only enforced if debsig-verify is installed.
  sudo mkdir -p "/etc/debsig/policies/$debsig_id" "/usr/share/debsig/keyrings/$debsig_id"
  curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol \
    | sudo tee "/etc/debsig/policies/$debsig_id/1password.pol" >/dev/null
  sudo gpg --dearmor --yes --output "/usr/share/debsig/keyrings/$debsig_id/debsig.gpg" "$tmp"
  rm -f "$tmp"

  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y 1password-cli
}

mise_tool() {
  if has mise; then
    log "mise already installed"
    return
  fi

  log "Installing mise"
  local keyring=/etc/apt/keyrings/mise-archive-keyring.asc
  curl -fsSL https://mise.jdx.dev/gpg-key.pub | sudo tee "$keyring" >/dev/null

  echo "deb [arch=arm64 signed-by=$keyring] https://mise.jdx.dev/deb stable main" \
    | sudo tee /etc/apt/sources.list.d/mise.list >/dev/null

  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mise
}

# Config files come from the dotfiles repo; mise then installs the tools that config lists
# (prebuilt arm64 Node, so nothing compiles on the Pi).
dotfiles() {
  # mise exec runs chezmoi before the global mise config exists on a fresh machine.
  if [[ -d ${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi/.git ]]; then
    log "Updating dotfiles"
    mise exec chezmoi@latest -- chezmoi update
  else
    log "Applying dotfiles from $DOTFILES_REPO"
    mise exec chezmoi@latest -- chezmoi init --apply "$DOTFILES_REPO"
  fi

  log "Installing tools from mise config"
  mise install
}

# Each machine gets its own GitHub key, so one can be revoked without affecting the others.
# No passphrase: unattended sessions need to push.
ssh_key() {
  local key="$HOME/.ssh/id_ed25519"
  if [[ -f $key ]]; then
    log "SSH key already exists"
    return
  fi

  log "Generating SSH key"
  mkdir -p -m 700 "$HOME/.ssh"
  ssh-keygen -q -t ed25519 -C "$(hostname)" -f "$key" -N ""

  warn "add this public key at https://github.com/settings/keys, then remove the old machine's key:"
  cat "$key.pub"
}

# Native installer: a self-updating arm64 binary in ~/.local/bin, independent of the Node version.
claude_code() {
  if has claude || [[ -x $HOME/.local/bin/claude ]]; then
    log "Claude Code already installed"
    return
  fi

  log "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
  warn "run 'claude' once to log in"
}

# Docker Engine from Docker's own apt repo, which also carries the compose and buildx plugins.
docker_engine() {
  if has docker; then
    log "Docker already installed"
    return
  fi

  log "Installing Docker Engine"
  local keyring=/etc/apt/keyrings/docker.asc tmp
  tmp="$(mktemp)"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$tmp"
  sudo install -D -m 644 "$tmp" "$keyring"
  rm -f "$tmp"

  # shellcheck disable=SC1091
  . /etc/os-release
  printf '%s\n' \
    'Types: deb' \
    'URIs: https://download.docker.com/linux/ubuntu' \
    "Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}" \
    'Components: stable' \
    'Architectures: arm64' \
    "Signed-By: $keyring" \
    | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null

  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Lets the user, the VS Code extensions and Claude Code reach the daemon without sudo.
# Membership is root in all but name; the README covers why that is accepted here.
docker_group() {
  if id -nG "$USER" | grep -qw docker; then
    log "$USER already in the docker group"
    return
  fi

  log "Adding $USER to the docker group"
  sudo usermod -aG docker "$USER"
  warn "log out and back in (and restart the VS Code server) for the docker group to apply"
}

# Extensions run on the Pi, inside the server that Remote-SSH installs on first connect, so
# they can only be installed once a laptop has connected. The list comes from the dotfiles.
EXTENSIONS_FILE="$HOME/.config/pi-dev-box/vscode-extensions.txt"

vscode_extensions() {
  if [[ ! -s $EXTENSIONS_FILE ]]; then
    warn "no $EXTENSIONS_FILE; skipping VS Code extensions"
    return
  fi

  # One server per VS Code release the laptop has connected with; use the newest.
  local server="" candidate
  for candidate in "$HOME"/.vscode-server/cli/servers/*/server/bin/code-server; do
    [[ -x $candidate ]] || continue
    [[ -z $server || $candidate -nt $server ]] && server=$candidate
  done

  if [[ -z $server ]]; then
    warn "no VS Code server yet; connect once with Remote-SSH, then re-run to install extensions"
    return
  fi

  local installed missing=() ext
  installed="$("$server" --list-extensions)"
  while read -r ext; do
    [[ -z $ext || $ext == \#* ]] && continue
    grep -qixF "$ext" <<<"$installed" || missing+=("$ext")
  done <"$EXTENSIONS_FILE"

  if ((${#missing[@]} == 0)); then
    log "VS Code extensions already installed"
    return
  fi

  log "Installing VS Code extensions: ${missing[*]}"
  for ext in "${missing[@]}"; do
    "$server" --install-extension "$ext" >/dev/null || warn "could not install $ext"
  done
}

# SSH is allowed only from the subnets in this file (one CIDR per line). The file stays on
# the machine, which keeps network details out of the public repo.
SUBNETS_FILE="$HOME/.config/pi-dev-box/ssh-allowed-subnets"

firewall() {
  if [[ ! -s $SUBNETS_FILE ]]; then
    warn "no $SUBNETS_FILE; skipping firewall (add one CIDR per line, then re-run)"
    return
  fi

  has ufw || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ufw

  log "Configuring firewall"
  sudo ufw default deny incoming >/dev/null
  sudo ufw default allow outgoing >/dev/null

  local subnet
  while read -r subnet; do
    [[ -z $subnet || $subnet == \#* ]] && continue
    sudo ufw allow from "$subnet" to any port 22 proto tcp >/dev/null
  done <"$SUBNETS_FILE"

  # Rules go in before the firewall is switched on, so the current SSH session is never cut off.
  sudo ufw --force enable >/dev/null
}

# Key-only SSH. The 10- prefix matters: sshd keeps the first value it reads, and Ubuntu's
# 50-cloud-init.conf can set PasswordAuthentication yes.
harden_ssh() {
  local conf=/etc/ssh/sshd_config.d/10-hardening.conf
  if [[ -f $conf ]]; then
    log "SSH already hardened"
    return
  fi

  if [[ ! -s $HOME/.ssh/authorized_keys ]]; then
    warn "no authorized SSH key for $USER; skipping SSH hardening to avoid a lockout"
    return
  fi

  log "Disabling SSH password and root login"
  printf '%s\n' \
    'PasswordAuthentication no' \
    'KbdInteractiveAuthentication no' \
    'PermitRootLogin no' \
    | sudo tee "$conf" >/dev/null

  if ! sudo sshd -t; then
    sudo rm -f "$conf"
    die "sshd rejected the new config; removed it"
  fi
  sudo systemctl reload ssh
}

# Ubuntu's Pi image gives the first user passwordless sudo. Override it, but only once the
# user has a password; otherwise sudo would be locked out for good.
require_sudo_password() {
  local rule=/etc/sudoers.d/99-require-password
  if sudo test -f "$rule"; then
    log "sudo already requires a password"
    return
  fi

  if [[ "$(sudo passwd -S "$USER" | awk '{print $2}')" != P ]]; then
    warn "no password set for $USER; run 'sudo passwd $USER', then re-run this script"
    return
  fi

  log "Requiring a password for sudo"
  local tmp
  tmp="$(mktemp)"
  echo "$USER ALL=(ALL:ALL) ALL" >"$tmp"
  sudo visudo -cf "$tmp" >/dev/null
  sudo install -m 440 -o root -g root "$tmp" "$rule"
  rm -f "$tmp"
}

main() {
  preflight
  base_packages
  github_cli
  onepassword_cli
  mise_tool
  dotfiles
  ssh_key
  claude_code
  docker_engine
  docker_group
  vscode_extensions
  firewall
  harden_ssh
  require_sudo_password
  log "Done"
}

main "$@"
