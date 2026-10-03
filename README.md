# pi-dev-box

Setup for a disposable remote development box: a Raspberry Pi 5 running Ubuntu Server 26.04 (arm64), used from a laptop over VS Code Remote-SSH for TypeScript and SvelteKit work, and by Claude Code running unattended.

The goal is that the Pi holds nothing worth keeping. If the drive dies, a fresh install plus one script brings it back.

## Rebuild from scratch

On a fresh Ubuntu Server 26.04 install, as your normal user:

```bash
curl -fsSL https://raw.githubusercontent.com/ztlhayden/pi-dev-box/main/bootstrap.sh -o bootstrap.sh
less bootstrap.sh   # read it before running it
bash bootstrap.sh
```

The script is idempotent: every step checks whether its work is already done, so it is safe to re-run after any change.

## What the script does

| Step | What | Why this way |
|---|---|---|
| Preflight | Checks architecture, Ubuntu release, and that root is on the NVMe | A Pi with an SD card inserted can silently boot from it instead |
| Base packages | git, curl, build tools, tmux | Some npm packages have no prebuilt arm64 binary and compile on install |
| GitHub CLI | From GitHub's apt repository | Ubuntu's own package is frozen at the release version and falls far behind |
| 1Password CLI | From 1Password's apt repository | Ubuntu does not package it |
| mise | From mise's apt repository | One tool for Node and other CLI versions; reads each project's own version file |
| Dotfiles | chezmoi applies this repo, then mise installs the tools listed in its config | Config lives here, not on the machine |

Still to come: Claude Code with a permission allowlist, and hardening (key-only SSH, a firewall limited to the local network and VPN, automatic security updates).

## What is in the repo

`bootstrap.sh` sits at the root. Everything under `home/` is managed by chezmoi and copied into the home folder; the one-line `.chezmoiroot` file tells chezmoi to look only there, which leaves the rest of the repo free for scripts and documentation.

| File | Lands at | Purpose |
|---|---|---|
| `home/dot_bash_aliases` | `~/.bash_aliases` | Turns on mise in interactive shells. Ubuntu's stock `.bashrc` already loads this file, so `.bashrc` is left alone. |
| `home/dot_bash_profile` | `~/.bash_profile` | Puts mise-managed tools on `PATH` for programs that never open an interactive shell, such as the VS Code server |
| `home/dot_gitconfig` | `~/.gitconfig` | Commit identity, and GitHub logins over HTTPS through `gh` |
| `home/dot_config/mise/config.toml` | `~/.config/mise/config.toml` | Global fallback tool versions |

Project-level config (ESLint, Prettier, Vitest, editor extensions, Node version) is deliberately not here. It belongs in each project's repository so it travels with the code.

## Design decisions

**Remote-SSH, not a VS Code tunnel.** A tunnel relays through a third party's servers. Remote-SSH stays on the local network or VPN, and nothing on the Pi is reachable from the internet.

**No secrets in this repo, which is why it can be public.** Anything sensitive is stored in 1Password and referenced by pointer (`op://vault/item/field`). A pointer is useless without access to the vault.

**The Pi has its own narrow credential instead of mine.** Claude Code sometimes works on the Pi while I am not connected, so forwarding my SSH key from the laptop is not enough. The Pi instead gets a fine-grained GitHub token limited to chosen repositories, with content and pull request permissions only. It can push branches and open pull requests; it cannot change settings or touch other repositories, and it can be revoked in one click. My personal key never leaves 1Password on the laptop.

**Commits from the Pi are unsigned.** Signing through a forwarded key would fail whenever I am not connected. Leaving Pi commits unsigned keeps the "Verified" badge meaning that I made the commit myself.

**chezmoi over symlinks.** It supports per-machine templates and can read values from 1Password when applying, which leaves room to manage the laptop from the same repo later.

## arm64 and Raspberry Pi notes

- Vendor apt repositories are pinned with `arch=arm64` so apt does not look for package lists that do not exist.
- mise downloads the official prebuilt arm64 Node, so nothing is compiled on the Pi.
- The Pi 5 boots from whichever device its EEPROM boot order prefers. The preflight step confirms root is actually on the NVMe.
- Ubuntu's Pi image ships with passwordless `sudo` for the first user. Convenient for a bootstrap script, and worth knowing about when deciding what an unattended agent may run.
- `.gitattributes` forces LF line endings. Editing this repo on Windows would otherwise turn `bootstrap.sh` into CRLF, which fails on Linux with a confusing `bad interpreter` error.
