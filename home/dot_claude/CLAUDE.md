# Working on this machine

This is a Raspberry Pi dev box. Sessions here often run unattended, with the user checking in from their phone. This file is managed in the pi-dev-box repo (`~/code/ztlhayden/pi-dev-box`); change it there, not here.

## Folders

Repositories live in `~/code`, cloned by GitHub owner:

- `~/code/ztlhayden/`: the user's personal account. `pi-dev-box` is this machine's setup: bootstrap script and the dotfiles chezmoi applies, including this file. Change it in this clone, on a branch; chezmoi keeps its own read-only copy in `~/.local/share/chezmoi`. `hayden-skills` is the user's public skills (`project-notes`, `run-sheet`, `ticket-run`, `run-retro`), linked into `~/.claude/skills`; change them in this clone.
- `~/code/Indy-Center/`: the Indy-Center organisation, shared with the team. Its own `CLAUDE.md` lists the repos.
- `~/code/ai-notes`: the user's private notes repo (see below).

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

Three repositories are the exception: agents own them, and may push to `main` without asking. The rule against force-pushing still applies.

- `ztlhayden/ai-notes`, cloned at `~/code/ai-notes`: private. Work on its `main` branch.
- `ztlhayden/hayden-skills`, cloned at `~/code/ztlhayden/hayden-skills`: public, so nothing from the notes repo (names, paths, ticket or run details) goes in it. Work on its `main` branch.
- `ztlhayden/pi-dev-box`, cloned at `~/code/ztlhayden/pi-dev-box`: this machine's setup. Make the change on a branch in a worktree, check it (`bash -n`, a dry run where one exists), then push it to `main` and apply it: `chezmoi git -- pull --ff-only`, read `chezmoi diff`, then `chezmoi apply` (or the matching step of `bootstrap.sh` for what chezmoi doesn't manage). Say in the report what changed for the machine.

## Commits and pull requests

- Group changes into commits that each do one thing a reader can understand without the others.
- Keep commit messages and pull request descriptions brief: what changed, and why it matters if that is not obvious.
- Leave out the history of how the change came about: approaches that were tried and dropped, debugging steps, and discussion from the session.

## This machine

- Do not use `sudo`. System-level changes belong in `bootstrap.sh` in the pi-dev-box repo.
- Do not read anything under `~/.ssh`.
- Change files with the Edit and Write tools: Read a file before you Edit it (Edit refuses a file you have only seen through `cat` or `sed -n`), one Edit per replacement, `replace_all` for a repeated one, Write for a new or whole file. Conflict markers: load the `resolving-merge-conflicts` skill. A hook blocks in-place shell rewrites (`sed -i`, scripts that write the file back).
- A check or server you started as a background task: wait for its notification; `sleep` is refused.
- Use the package manager the project's repo map names (its Tooling column); pnpm where it names none. If a package manager asks to approve a package's install script, ask the user first.
- Give each new git worktree its own install, with the repo's package manager (`pnpm install`, or `npm ci` where the lockfile is npm's). Vite's dev server refuses files outside the worktree, so a `node_modules` linked from the main checkout breaks the page's scripts.
- Browser checks of your own work use `playwright-cli` (its skill). Before the first browser command read `~/.claude/skills/playwright-cli/references/this-machine.md`: which browser, sessions, local servers, sizes and screenshots on this machine.

## Agent skills

Shared by every project on this machine. The notes themselves are in the private notes repo, `~/code/ai-notes`; the conventions and scripts are the `project-notes` skill, `~/.claude/skills/project-notes/`.

### Issue tracker

Tickets are GitHub issues on the private `ztlhayden/ai-notes`; a feature is a milestone, and its spec stays a file in `~/code/ai-notes/<project>/tickets/`. Before working on an issue, read `~/.claude/skills/project-notes/issue-tracker.md`: labels, claiming, triage, blockers and the board. Features not yet moved stay markdown tickets under `tickets/` until the migration; that file covers them too, with `ticket.py` and `check-tickets.py` beside `issues.py` in `~/.claude/skills/project-notes/scripts/`.

When the user refers to a ticket, by number, link, title or feature name:

- Look on GitHub first (`python3 ~/.claude/skills/project-notes/scripts/issues.py show <n>`, or `gh issue list -R ztlhayden/ai-notes --search '<words>'`), then the markdown tickets. The repo is private: read it with `gh` or the helper, never by fetching the link.
- A bare `#13` names an ai-notes ticket when the user calls it a ticket or the session is in ai-notes. In a code repo it may be that repo's own issue or pull request, and "PR #41" always is. If it's unclear, check both and say which you found.

`python3 ~/.claude/skills/project-notes/scripts/issues.py` keeps reads short, from any folder:

- `survey [<milestone>]`: one line per milestone with its count of each status, and the issues an agent can start. Start a survey here instead of reading issues.
- `show <n>`: an issue with all but the last comment folded, for surveys only. Read it whole (`show --all <n>`) before working on it: its comments hold open questions, branches and handoff notes.
- `chain <n>`: what it waits on, to the end of its *blocked by* links.

### Triage labels

The five default roles, kept as a `status:` label on each issue (`wontfix` is closed as not planned). See `~/.claude/skills/project-notes/triage-labels.md`.

### Domain docs

One glossary and set of decisions per project folder in `~/code/ai-notes`; its `README.md` lists the subjects that share one folder. See `~/.claude/skills/project-notes/domain.md`.

### Repo maps

A project's notes live in `~/code/ai-notes`, apart from its code, because one project can span several repos. Each project's `README.md` there maps its repos: where work lands, and with what tooling. Read `~/.claude/skills/project-notes/repo-map.md` before building from tickets or across repos, and whenever a fact in a map changes.

### Ticket runs

Unattended runs build a feature's `ready-for-agent` issues with worker agents: `/run-sheet <milestone or feature folder>` drafts the run's sheet, `/ticket-run <run sheet>` starts the run, `/run-retro` measures it afterwards. The cycle around them is `~/.claude/skills/ticket-run/run-cycle.md`; the orchestrator and role briefs are in `~/.claude/skills/ticket-run/briefs/`. A ticket turns `ready-for-agent` only after `~/.claude/skills/project-notes/ticket-checklist.md`.
