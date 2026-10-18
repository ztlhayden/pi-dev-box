# Indy Center projects

The team's engineering docs are at https://tech.flyindycenter.com. Fetch the matching page before setting up or running a repo here, or deciding how to branch, use Jira, or wire up auth, Workers or CI:

- `/start-here/`: how the services fit together
- `/projects/`: every repo, and whether it is still active
- `/development/setup/`: local setup, environment, common commands
- `/patterns/auth/`: auth, Worker shapes, RPC versus Queues, CI workflows
- `/agreements/definition-of-done/`: definition of done, Jira, branching, CI

For the whole site in one fetch (about 100 KB), use `/llms-full.txt`; `/llms.txt` indexes it.

The docs set each project's conventions; this machine's GitHub and safety rules still apply on top. When a page disagrees with the code, tell the user which one looks right.

Use the package manager the repo's lockfile names: `package-lock.json` is npm, `pnpm-lock.yaml` is pnpm. This replaces the machine-wide pnpm rule for repos here. npm on this machine skips install scripts, as pnpm does; when a package fails because its script never ran, ask the user before running `npm rebuild <package>`.

Start dev servers as tracked background tasks, so the session can stop them by task.

## Repos cloned here

From the Indy-Center GitHub organisation. `/projects/` on the docs site is the full list and says which are active.

| Folder | What it is |
| --- | --- |
| `brand-guide` | brand.flyindycenter.com: the brand guide's pages and the logo and mark files |
| `community-website` | flyindycenter.com (SvelteKit): roster, events, feedback, partners, admin |
| `developer-portal` | tech.flyindycenter.com, the team's engineering docs (Astro Starlight) |
| `docker-infrastructure` | Traefik reverse-proxy config for the Vanderbilt VPS |
| `identity` | Sign-in Worker for `*.flyindycenter.com` (VATSIM Connect, sessions, RPC) |
| `indy-larry` | Discord bot showing which ZID facilities are staffed on vNAS |
| `indy-library` | Document library for pilots and controllers (SvelteKit on Workers) |
| `payload` | Payload CMS at cms.flyindycenter.com, on the Vanderbilt VPS |
| `postiz` | Social media scheduler for the events team |
| `scheddy` | Session scheduling; a fork of ZTL's scheddy |
| `teamspeak-server` | TeamSpeak 3 voice server, on the Vanderbilt VPS |
| `training-tools` | training.flyindycenter.com: controller training management (SvelteKit) |
