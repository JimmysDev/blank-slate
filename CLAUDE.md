# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## State Detection

**Check the current state of this repo before doing anything:**

- If `infra/` directory exists AND `project.json` does NOT exist → **this is an unconfigured blank-slate**. Follow the "First-Time Setup" flow below.
- If `project.json` exists → this is a configured project. Read the Project Overview section and work normally.

## Project Overview

<!-- SETUP: Claude will replace this section after provisioning -->
This project was created from the blank-slate template. Run `/hi-claude` to configure it.

**Stack:** <!-- SETUP: filled in after provisioning -->

## First-Time Setup Flow

When a user runs `/hi-claude` or asks to set up this project:

### Step 1: Ask One Question

"What do you want to build?" — accept free-text description. If the user passed `$ARGUMENTS`, use that.

### Step 2: Determine Requirements

From the user's description, infer:
- **Stack:** Python (Flask) or Node (Express) — ask if ambiguous
- **Database:** needed if description mentions storage, users, data, accounts
- **Auth:** needed if description mentions login, users, accounts, authentication
- **File storage:** needed if description mentions uploads, files, images, audio
- **Custom domain:** ask explicitly — suggest `<project>.jimmys.dev`

### Step 3: Present Plan and Confirm

Example: "I'll set up: Railway project with Postgres + Volume, GitHub repo `JimmysDev/<name>`, Auth0 app, domain at foo.jimmys.dev. Sound good?"

### Step 4: Progressive Provisioning

Only check credentials for services actually needed. Run scripts in order:

1. `bash infra/credential-check.sh railway` — if fails, give install command, wait
2. `bash infra/credential-check.sh github` — if fails, give install command, wait
3. `bash infra/github-setup.sh --name <name> --owner JimmysDev`
4. `bash infra/railway-setup.sh --name <name> [--postgres] [--volume /data] [--domain <domain>]`
5. Copy appropriate template files into project root:
   - `templates/Dockerfile.<stack>` → `Dockerfile`
   - `templates/railway.json` → `railway.json`
   - `templates/start.sh` → `start.sh`
   - `templates/app-stubs/<stack>/*` → project root (preserving directory structure)
6. If auth needed: `bash infra/credential-check.sh auth0` then `bash infra/auth0-setup.sh --name <name> --domain <app-url>`
7. If custom domain with GoDaddy: `bash infra/credential-check.sh dns` (credentials in env)
8. Rewrite this `CLAUDE.md`:
   - Replace "Project Overview" with real project description and stack
   - Remove the entire "First-Time Setup Flow" section
   - Keep "Session Protocol", "Git & CI/CD Workflow", "Git Conventions", "Code Rules"
   - Add "Railway-Managed Files" section listing Dockerfile and railway.json
9. Create `project.json` with all config (name, stack, services, domain, github repo)
10. Delete scaffolding: `rm -rf infra/ templates/ migrate/ docs/`
11. Initial commit + push → GitHub Action auto-merges → Railway auto-deploys
12. **ONE MANUAL STEP:** Tell the user to connect the GitHub repo in Railway dashboard. Print the exact URL: `https://railway.com/project/<id>/service/<id>/settings` → Source → Connect `<owner>/<repo>` on branch `main`
13. Poll the `/health` endpoint until it responds (Docker builds take 3-7 min)

### Step 5: Report Success

Print live links: app URL, Railway dashboard, GitHub repo, Auth0 dashboard (if applicable).

### Migration Flow (when user mentions "migrate" or "Replit")

1. Don't scaffold new code — use their existing code
2. Add `storage/filesystem.py` if they used Replit Object Storage
3. Add Dockerfile and railway.json
4. Migrate database: generate `pg_dump | pg_restore` command for user to run (Claude never sees credentials)
5. Migrate secrets: generate `railway variables --set` commands — user runs them
6. Migrate storage: use `migrate/migrate-storage.py` with MIGRATION_SECRET endpoints
7. Update Auth0 callback URLs for new domain

## Session Protocol

**Before writing code:**
1. Read this CLAUDE.md
2. Read `ARCHITECTURE.md` (if it exists)
3. Read the last 10 entries in `CHANGES.md` (if it exists)

**Before considering a task complete:**
1. Smoke test passes
2. `CHANGES.md` updated
3. Everything committed

## Git & CI/CD Workflow

- **Always create a pull request** after pushing changes to a branch. Never leave changes on a branch without a PR.
- **Target branch:** `main`
- Auto-PR workflow handles merge. Railway auto-deploys when main updates (after GitHub repo is linked in dashboard).
- No deploy webhooks needed — Railway watches the repo directly.

## Git Conventions

Commit format: `[type]: short description` where type is one of: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`. Never commit broken code.

## Code Rules

- Files under 300 lines; split if exceeded
- No magic values — constants go in config
- No inline TODOs — use `TODO.md`
- Type hints/schemas on all cross-layer interfaces
- Tests live next to the code they test
- Dependencies require justification logged in `CHANGES.md`

## Secret Handling — CRITICAL

Claude must NEVER see secret values. Pattern:
- Generate commands for the user to run where secrets pipe directly from source to destination
- Verify by checking key names only: `railway variables --json | python3 -c "import sys,json; print(list(json.load(sys.stdin).keys()))"`
- Use single-quoted values with `railway variables --set 'KEY=value'` to avoid trailing newlines

## Railway CLI Gotchas

- `railway variables --set` adds trailing newline to values — always single-quote: `'KEY=value'`
- Env vars set via CLI only take effect on NEXT deploy — run `railway redeploy --service <name> --yes` after
- Always pass `--service <name>` to avoid interactive prompts
- `railway redeploy` requires `--yes` in non-interactive mode
- Docker builds take 3-7 min — poll `/health` after deploy, don't assume it's ready
- GitHub repo linking CANNOT be done via CLI — one manual dashboard step
- Railway Volumes persist across deploys — `/data` is the default mount point
