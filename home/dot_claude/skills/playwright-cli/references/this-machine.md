# playwright-cli on this machine

Read before the first browser command. `~/.claude/CLAUDE.md` points here; the rules below are the
Pi's, not playwright-cli's.

- **Which browser.** `playwright-cli` drives a headless Chromium for checking your own work on
  logged-out pages: a local dev server, an HTML file or artifact, a public site. Pages behind the
  user's logins stay with Claude in Chrome on their laptop, so ask the user.
- **Installed by `bootstrap.sh`**, which pins its version. If the command is missing, ask the user
  to run that script rather than installing it yourself.
- **Your own named session**, `-s=<repo-or-worktree>`, closed when you are done: every agent on
  the machine shares the sessions.
- **Local files go over HTTP**; the CLI refuses `file://` URLs. Start
  `python3 -m http.server <port> --bind 127.0.0.1 --directory <folder>` as a tracked background
  task, open `http://127.0.0.1:<port>/`, and stop the server when done. A Next.js dev server is
  the exception: open it at `http://localhost:<port>`, since at `127.0.0.1` it refuses its own
  scripts (`allowedDevOrigins`).
- **Sizes.** Tailwind v4's default breakpoints: phone 390×844 (below `sm`), tablet 768×1024
  (`md`), desktop 1280×800 (`xl`). In a project with its own breakpoints, pick widths inside its
  ranges. All three sizes when a change touches layout; phone alone for a small change.
- **A repo's own browser tests** can run on this Chromium: `$CHROMIUM_PATH` holds its path, for
  Playwright's `executablePath`. Leave `playwright install` unrun: it can delete other Chromium
  builds, breaking playwright-cli.
- **Screenshots** taken to check your work are temporary; the CLI saves them under
  `~/.cache/playwright-cli/`. Keep one for documentation when the user or a ticket asks, or when
  one would help a reader: save it with `--filename` next to the doc that uses it, named for what
  it shows. Some repos are public: check nothing private is visible before committing it.
