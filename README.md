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

### What the script leaves to you

A few steps involve credentials or details that are kept out of this repo, so they stay manual. The script skips the steps that depend on them and says so; do these, then run it again.

| Step | How | What waits on it |
|---|---|---|
| Authorise your laptop's SSH key | Set it when imaging the drive, so the first login already uses a key | Key-only SSH is skipped until a key is authorised |
| Set a password for your user | `sudo passwd $USER` | The sudo password step, which would otherwise lock sudo for good |
| List the networks allowed to SSH in | One CIDR per line in `~/.config/pi-dev-box/ssh-allowed-subnets` | The firewall |
| Add the machine's new key to GitHub | The script prints the public key; add it under Settings → SSH and GPG keys, and remove the old machine's key | Pushing to GitHub |
| Log in to Claude Code | Run `claude` and follow the browser login | Using Claude Code |

## What the script does

| Step | What | Why this way |
|---|---|---|
| Preflight | Checks architecture, Ubuntu release, and that root is on the NVMe | A Pi with an SD card inserted can silently boot from it instead |
| Base packages | git, curl, build tools, tmux | Some npm packages have no prebuilt arm64 binary and compile on install |
| GitHub CLI | From GitHub's apt repository | Ubuntu's own package is frozen at the release version and falls far behind |
| 1Password CLI | From 1Password's apt repository | Ubuntu does not package it |
| mise | From mise's apt repository | One tool for Node and other CLI versions; reads each project's own version file |
| Dotfiles | chezmoi applies this repo, then mise installs the tools listed in its config | Config lives here, not on the machine |
| SSH key | Generates a GitHub key for this machine if it has none, and prints the public half | One key per machine, so any one can be revoked alone |
| Claude Code | Anthropic's native installer | A self-updating arm64 binary that does not depend on which Node version a project pins |
| Firewall | ufw allows SSH only from subnets listed in a file kept on the machine | Network details stay out of this public repo; skipped if the file is missing |
| Key-only SSH | Turns off password and root login | Skipped if no SSH key is authorised, so it cannot lock the owner out |
| sudo password | Overrides the image's passwordless sudo | An unattended process cannot become root; skipped if the user has no password yet, which would otherwise lock sudo for good |

Automatic security updates are already on by default in Ubuntu Server, so the script leaves them alone.

## What is in the repo

`bootstrap.sh` sits at the root. Everything under `home/` is managed by chezmoi and copied into the home folder; the one-line `.chezmoiroot` file tells chezmoi to look only there, which leaves the rest of the repo free for scripts and documentation.

| File | Lands at | Purpose |
|---|---|---|
| `home/dot_bash_aliases` | `~/.bash_aliases` | Turns on mise in interactive shells. Ubuntu's stock `.bashrc` already loads this file, so `.bashrc` is left alone. |
| `home/dot_bash_profile` | `~/.bash_profile` | Puts mise-managed tools on `PATH` for programs that never open an interactive shell, such as the VS Code server |
| `home/dot_gitconfig` | `~/.gitconfig` | Commit identity and default branch name |
| `home/dot_config/mise/config.toml` | `~/.config/mise/config.toml` | Global fallback tool versions |
| `home/dot_claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Rules Claude Code follows on this machine: which repositories, how to branch, commit and push |
| `home/dot_claude/settings.json` | `~/.claude/settings.json` | Permissions enforced by Claude Code itself: routine commands pre-approved, `sudo` and force-pushes blocked |

Project-level config (ESLint, Prettier, Vitest, editor extensions, Node version) is deliberately not here. It belongs in each project's repository so it travels with the code.

## Design decisions

**Remote-SSH, not a VS Code tunnel.** A tunnel relays through a third party's servers. Remote-SSH stays on the local network or VPN, and nothing on the Pi is reachable from the internet.

**No secrets in this repo, which is why it can be public.** The only credential on the Pi is an SSH key generated there, and it never leaves the machine. Anything else sensitive would be stored in 1Password and referenced by pointer (`op://vault/item/field`), which is useless without access to the vault.

**The Pi has its own GitHub key instead of mine.** Claude Code sometimes works on the Pi while I am not connected, so forwarding my SSH key from the laptop is not enough. Each machine generates its own key, which I add to my GitHub account. My personal key never leaves 1Password on the laptop, and a lost or retired Pi is cut off by deleting one key.

**An account-wide key is a deliberate tradeoff.** The alternative was a fine-grained token limited to chosen repositories. It is narrower, but it expires, needs a repository list kept up to date, and brings a secrets manager onto the Pi. I chose the simpler key and limited the risk in other ways:

- A rules file tells Claude which repositories it may touch, to branch for every change, and never to push to `main` without a specific OK.
- Claude Code's own permission settings block `sudo`, force-pushes, and reading the key through its file tools.
- pnpm replaces npm, because it does not run dependencies' install scripts unless approved. A malicious package is the most realistic way a key on a dev box gets stolen.
- Nothing on the Pi is reachable from the internet.

**Commits from the Pi are unsigned.** Signing through a forwarded key would fail whenever I am not connected. Leaving Pi commits unsigned keeps the "Verified" badge meaning that I made the commit myself.

**chezmoi over symlinks.** It supports per-machine templates and can read values from 1Password when applying, which leaves room to manage the laptop from the same repo later.

## arm64 and Raspberry Pi notes

- Vendor apt repositories are pinned with `arch=arm64` so apt does not look for package lists that do not exist.
- mise downloads the official prebuilt arm64 Node, so nothing is compiled on the Pi.
- The Pi 5 boots from whichever device its EEPROM boot order prefers. The preflight step confirms root is actually on the NVMe.
- Ubuntu's Pi image ships with passwordless `sudo` for the first user. Convenient for a bootstrap script, and worth knowing about when deciding what an unattended agent may run.
- `.gitattributes` forces LF line endings. Editing this repo on Windows would otherwise turn `bootstrap.sh` into CRLF, which fails on Linux with a confusing `bad interpreter` error.
