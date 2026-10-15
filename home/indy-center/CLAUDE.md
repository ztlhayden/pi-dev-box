# Indy Center projects

The team's engineering docs are at https://tech.flyindycenter.com. Fetch the matching page before setting up or running a repo here, or deciding how to branch, use Jira, or wire up auth, Workers or CI:

- `/start-here/`: how the services fit together
- `/projects/`: every repo, and whether it is still active
- `/development/setup/`: local setup, environment, common commands
- `/patterns/auth/`: auth, Worker shapes, RPC versus Queues, CI workflows
- `/agreements/definition-of-done/`: definition of done, Jira, branching, CI

The docs set each project's conventions; this machine's GitHub and safety rules still apply on top. When a page disagrees with the code, tell the user which one looks right.

Use the package manager the repo's lockfile names: `package-lock.json` is npm, `pnpm-lock.yaml` is pnpm. This replaces the machine-wide pnpm rule for repos here. npm on this machine skips install scripts, as pnpm does; when a package fails because its script never ran, ask the user before running `npm rebuild <package>`.
