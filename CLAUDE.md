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

### Migration Flow (when user mentions "migrate", "import", or "Replit")

When a user wants to bring an existing Replit project into the blank-slate system, the goal is: **at the end, the repo should look as though this project was always a blank-slate project.** No trace of Replit. No leftover scaffolding.

#### Step M1: Get the Code

The user's code likely lives only on Replit with no local copy and no GitHub repo. Don't try to scrape Replit or access it via URL — that won't work for private Repls.

**Immediately create the destination folder:**
```bash
mkdir -p replit-source
```

**Easiest option — zip download (recommend this first):**
Tell the user step by step:
1. In Replit, open the project, click the three dots (⋯) at the top of the file panel → "Download as zip"
2. Move the downloaded zip file into the `replit-source/` folder that you just created (give them the full path, e.g. `~/Documents/Coding/local-repos/<project>/replit-source/`)
3. Let you know when it's there

Once they confirm, extract it:
```bash
unzip -o replit-source/<filename>.zip -d replit-source/
rm replit-source/<filename>.zip
```
If the zip was dropped in the project root instead:
```bash
unzip -o <filename>.zip -d replit-source/
rm <filename>.zip
```
Replit zips sometimes nest everything inside a subdirectory. If `replit-source/` contains a single folder with all the files inside it, move everything up:
```bash
mv replit-source/<nested-folder>/* replit-source/<nested-folder>/.* replit-source/ 2>/dev/null
rmdir replit-source/<nested-folder>
```

**If the Replit project is already synced with GitHub:**
Ask the user for the repo name and clone it directly:
```bash
git clone https://github.com/<owner>/<repo>.git replit-source
```
This is the fastest path — no zip, no manual steps.

**Alternative — push from Replit's shell to GitHub:**
This is more involved (requires `gh` or git auth on Replit). Only suggest this if the user specifically asks.
```bash
git init && git add -A && git commit -m "export from replit"
gh repo create JimmysDev/<name> --private --source=. --push
```
Then clone locally into `replit-source/`.

**Important:** Always put the imported code in `replit-source/`, never directly in the project root. This avoids conflicts with blank-slate files (both may have CLAUDE.md, .gitignore, etc). The blank-slate agent handles creating the GitHub repo later as part of provisioning — the user doesn't need to do it themselves.

#### Step M2: Explore and Discover

Read through `replit-source/` to understand:
- **Stack:** Python/Flask, Node/Express, etc.
- **Database:** Check for `DATABASE_URL` usage, SQLAlchemy models, Prisma schema, etc.
- **Auth:** Look for Auth0, OAuth, session management
- **Storage:** Look for `from replit.object_storage import Client` or similar
- **Secrets/env vars:** Check `.replit`, any env references, Replit Secrets usage
- **System deps:** Check `replit.nix` for packages like ffmpeg, Playwright, etc.
- **Run command:** Check `.replit` for how the app starts

Present what you found and ask the user to confirm. Ask about:
- Custom domain (suggest `<project>.jimmys.dev`)
- Any services that need reconnecting (Auth0 callback URLs, etc.)

#### Step M3: Provision Infrastructure

Use the same provisioning steps as a new project (Step 4 above), but:
- Create the GitHub repo with `infra/github-setup.sh` (if not already created in M1)
- Create Railway project with appropriate services based on what you discovered
- If Auth0: create new Auth0 app OR ask user to update existing callback URLs

#### Step M4: Adapt the Code

Move files from `replit-source/` into the project root, making these changes:
- **Replace Replit Object Storage** with `storage/filesystem.py` from `templates/app-stubs/python/storage/` (or Node equivalent). Update imports throughout the code.
- **Add `Dockerfile`** — use the appropriate template but add any system dependencies found in `replit.nix` (e.g. ffmpeg, Playwright chromium deps)
- **Add `railway.json`** from templates
- **Add `start.sh`** if needed
- **Remove Replit files:** `.replit`, `replit.nix`, `replit-deploy.json`, `.replit.deploy`, any `repl.deploy` binary
- **Update `.gitignore`** — merge the imported project's gitignore with blank-slate's
- **Preserve the app code** — don't restructure or refactor the user's code. Just make the minimal changes needed to run on Railway.

#### Step M5: Handle Data Migration

Walk the user through these (they run the commands — Claude never sees credentials):

1. **Database:** Generate `pg_dump | pg_restore` commands. See `migrate/migrate-database.sh`.
2. **Secrets:** List the env var names the app needs (from reading the code). Generate `railway variable set 'KEY=<value>'` commands for the user to fill in and run.
3. **Blob storage:** If the app used Replit Object Storage, walk through the `migrate/migrate-storage.py` flow — add temporary migration endpoints, set MIGRATION_SECRET, run script on Replit. See `migrate/README.md`.
4. **Auth0 callbacks:** If Auth0, tell user to add new Railway domain to callback/logout/origins URLs (keep old URLs until confirmed working).

#### Step M6: Finalize

Same as new project Steps 8-13:
- Clean up `replit-source/` directory: `rm -rf replit-source/`
- Rewrite CLAUDE.md with real project info
- Create `project.json`
- Delete scaffolding: `rm -rf infra/ templates/ migrate/ docs/`
- Commit, push, set up Railway GitHub link (manual step)
- Verify `/health` endpoint

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

## Local Dev with Tailscale

Tailscale makes the local dev server accessible from any device on the tailnet (phone, other computers).

- Mac hostname on tailnet: `jimmys-mac-mini`
- Access local dev server from phone: `http://jimmys-mac-mini:<port>` (e.g. `:5000` for Flask)
- Tailscale must be running on both the Mac and the accessing device
- Keep Tailscale updated: `brew upgrade --cask tailscale`

## Homebrew Maintenance

Keep CLI tools updated periodically:
```bash
brew upgrade railway gh auth0 tailscale
brew upgrade --cask tailscale
```

## Railway CLI Gotchas

- `railway variables --set` adds trailing newline to values — always single-quote: `'KEY=value'`
- Env vars set via CLI only take effect on NEXT deploy — run `railway redeploy --service <name> --yes` after
- Always pass `--service <name>` to avoid interactive prompts
- `railway redeploy` requires `--yes` in non-interactive mode
- Docker builds take 3-7 min — poll `/health` after deploy, don't assume it's ready
- GitHub repo linking CANNOT be done via CLI — one manual dashboard step
- Railway Volumes persist across deploys — `/data` is the default mount point
