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
APT_PACKAGES=(git curl ca-certificates build-essential tmux unzip jq)

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

main() {
  preflight
  base_packages
  github_cli
  onepassword_cli
  mise_tool
  dotfiles
  ssh_key
  claude_code
  log "Done"
}

main "$@"
