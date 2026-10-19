# Working on this machine

This is a Raspberry Pi dev box. Sessions here often run unattended, with the user checking in from their phone. This file is managed in the pi-dev-box repo (`~/ztlhayden/pi-dev-box`); change it there, not here.

## Folders

Repositories are cloned by GitHub owner:

- `~/ztlhayden/`: the user's personal account. `pi-dev-box` is this machine's setup: bootstrap script and the dotfiles chezmoi applies, including this file. Change it in this clone, on a branch; chezmoi keeps its own read-only copy in `~/.local/share/chezmoi`.
- `~/indy-center/`: the Indy-Center organisation, shared with the team. Its own `CLAUDE.md` lists the repos.
- `~/ai-notes`: the user's private notes repo (see below).

A `<repo>.<name>` folder beside a repo is a git worktree of it.

## GitHub

This machine's SSH key can reach every repository on the user's account, including organisation repositories shared with other people. Being able to reach a repository is not permission to work in it.

- Ask before reading from, cloning, or changing any repository the user has not named in this session.
- Create a branch for each feature or fix. Do not work directly on the default branch. A feature is the whole piece of work: all of its tickets share its one branch and land in one pull request.
- Never push to `main` (or whatever the default branch is) without a specific OK for that push. An OK given earlier does not carry over to the next push.
- Never force-push.
- Push the branch at the end of every session, so no work is left only on this machine.
- Push in the foreground, one branch per command, under `timeout`, and check its output. Pushes to GitHub from this machine sometimes stall; retry a stalled one rather than waiting on it in the background.
- Ask before opening a pull request.

The `ztlhayden/ai-notes` repository (cloned at `~/ai-notes`) is the exception: agents own it. Work on its `main` branch and push to `main` without asking. The rule against force-pushing still applies.

## Commits and pull requests

- Group changes into commits that each do one thing a reader can understand without the others.
- Keep commit messages and pull request descriptions brief: what changed, and why it matters if that is not obvious.
- Leave out the history of how the change came about: approaches that were tried and dropped, debugging steps, and discussion from the session.

## This machine

- Do not use `sudo`. System-level changes belong in `bootstrap.sh` in the pi-dev-box repo.
- Do not read anything under `~/.ssh`.
- Change files with the Edit and Write tools; a hook blocks in-place shell rewrites (`sed -i`, scripts that write the file back).
- Use the package manager the project's repo map names (its Tooling column); pnpm where it names none. If a package manager asks to approve a package's install script, ask the user first.
- Give each new git worktree its own install, with the repo's package manager (`pnpm install`, or `npm ci` where the lockfile is npm's). Vite's dev server refuses files outside the worktree, so a `node_modules` linked from the main checkout breaks the page's scripts.
- `playwright-cli` (see its skill) drives a headless Chromium for checking your own work on logged-out pages: a local dev server, an HTML file or artifact, a public site. Pages behind the user's logins stay with Claude in Chrome on their laptop, so ask the user. `bootstrap.sh` pins its version; if the command is missing, ask the user to run that script rather than installing it yourself.
  - Use your own named session (`-s=<repo-or-worktree>`) and close it when done: every agent on the machine shares the sessions.
  - Check at Tailwind v4's default breakpoints: phone 390×844 (below `sm`), tablet 768×1024 (`md`), desktop 1280×800 (`xl`). In a project with its own breakpoints, pick widths inside its ranges. All three sizes when a change touches layout; phone alone for a small change.
  - Screenshots taken to check your work are temporary; the CLI saves them under `~/.cache/playwright-cli/`.
  - Keep a screenshot for documentation when the user or a ticket asks, or when one would help a reader. Save it with `--filename` next to the doc that uses it, named for what it shows. Some repos are public: check nothing private is visible before committing it.

## Agent skills

Shared by every project on this machine. The files are in the private notes repo, `~/ai-notes`.

### Issue tracker

Local markdown tickets under `~/ai-notes/<project>/tickets/`. See `~/ai-notes/agents/issue-tracker.md`.

### Triage labels

The five default roles, kept as a `Status:` line in each ticket. See `~/ai-notes/agents/triage-labels.md`.

### Domain docs

One glossary and set of decisions per project folder in `~/ai-notes`. See `~/ai-notes/agents/domain.md`.

### Repo maps

A project's notes live in `~/ai-notes`, apart from its code, because one project can span several repos. Each project's `README.md` there maps its repos: where work lands, and with what tooling. Read `~/ai-notes/agents/repo-map.md` before building from tickets or across repos, and whenever a fact in a map changes.
