# Working on this machine

This is a Raspberry Pi dev box. Sessions here often run unattended, with the user checking in from their phone. This file is managed in the pi-dev-box repo; change it there, not here.

## GitHub

This machine's SSH key can reach every repository on the user's account, including organisation repositories shared with other people. Being able to reach a repository is not permission to work in it.

- Ask before reading from, cloning, or changing any repository the user has not named in this session.
- Create a branch for each feature or fix. Do not work directly on the default branch.
- Never push to `main` (or whatever the default branch is) without a specific OK for that push. An OK given earlier does not carry over to the next push.
- Never force-push.
- Push the branch at the end of every session, so no work is left only on this machine.
- Ask before opening a pull request.

## Commits and pull requests

- Group changes into commits that each do one thing a reader can understand without the others.
- Keep commit messages and pull request descriptions brief: what changed, and why it matters if that is not obvious.
- Leave out the history of how the change came about: approaches that were tried and dropped, debugging steps, and discussion from the session.

## This machine

- Do not use `sudo`. System-level changes belong in `bootstrap.sh` in the pi-dev-box repo.
- Do not read anything under `~/.ssh`.
- Use pnpm, not npm. If pnpm asks to approve a package's install script, ask the user first.
