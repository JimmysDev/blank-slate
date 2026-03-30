# blank-slate Setup Instructions

These are the provisioning instructions for the `/blank-slate-setup` skill. Read this file when setting up a new project, importing from Replit, or adding infrastructure to an existing repo.

---

## Flow Detection

Determine which flow to follow based on what's in the repo:

1. **Empty repo** (no source files beyond blank-slate's own): → **New Project Flow**
2. **Has Replit files** (`.replit`, `replit.nix`, or user says "import from Replit"): → **Replit Import Flow**
3. **Has existing code** (source files, possibly its own CLAUDE.md): → **Existing Repo Flow**

---

## New Project Flow

### Step 1: Ask One Question

"What do you want to build?" — accept free-text description. If the user passed `$ARGUMENTS` to the skill, use that.

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

### Step 5: Finalize

1. Set up CLAUDE.md:
   - If no CLAUDE.md exists: copy the full blank-slate CLAUDE.md (it's already there if this is a blank-slate clone)
   - Replace "Project Overview" with real project description and stack
   - Remove setup flow references
   - Ensure standard sections are present (or append from `infra/claude-md-sections.md`)
2. Create `project.json` with all config (name, stack, services, domain, github repo)
3. Delete scaffolding: `rm -rf infra/ templates/ migrate/ docs/ BLANK_SLATE_PLAN.md`
4. Initial commit + push → GitHub Action auto-merges → Railway auto-deploys
5. **ONE MANUAL STEP:** Tell the user to connect the GitHub repo in Railway dashboard. Print the exact URL: `https://railway.com/project/<id>/service/<id>/settings` → Source → Connect `<owner>/<repo>` on branch `main`
6. Poll the `/health` endpoint until it responds (Docker builds take 3-7 min)

### Step 6: Report Success

Print live links: app URL, Railway dashboard, GitHub repo, Auth0 dashboard (if applicable).

---

## Replit Import Flow

When a user wants to bring an existing Replit project into the system. The goal: **at the end, the repo should look as though this project was always provisioned through blank-slate.** No trace of Replit. No leftover scaffolding.

**Assume a full migration.** "Import from Replit" means everything — code, database, blob storage, secrets, the lot. Don't ask "do you want to migrate your data too?" after deploying the code. Plan for data migration from the start (Step M2) and execute it as part of the flow (Step M5).

### Step M1: Get the Code

Check if user code is already in the project root (agency may have put it there). Look for source files like `app.py`, `main.py`, `index.js`, `package.json`, etc. alongside `infra/`.

**If code is already in the root:** Skip to Step M2. Agency assembled the project.

**If the project root only has blank-slate files:** The user needs to get their code. Follow this process:

**Immediately create the destination folder in the repo root (not the worktree):**
If you're in a worktree, find the main repo root first:
```bash
REPO_ROOT=$(git worktree list | head -1 | awk '{print $1}')
mkdir -p "$REPO_ROOT/replit-source"
```
If not in a worktree, just `mkdir -p replit-source`.

**Easiest option — zip download (recommend this first):**
Tell the user step by step:
1. In Replit, open the project, click the three dots (⋯) at the top of the file panel → "Download as zip"
2. Move the downloaded zip file into the `replit-source/` folder that you just created (give them the full path using `$REPO_ROOT/replit-source/`, e.g. `~/Documents/Coding/local-repos/<project>/replit-source/`)
3. Let you know when it's there

Once they confirm, find and extract the zip:
```bash
# Extract (handles zip in replit-source/ or project root)
unzip -o "$REPO_ROOT/replit-source"/*.zip -d "$REPO_ROOT/replit-source/" 2>/dev/null || \
unzip -o "$REPO_ROOT"/*.zip -d "$REPO_ROOT/replit-source/" 2>/dev/null
# Clean up the zip
rm -f "$REPO_ROOT/replit-source"/*.zip "$REPO_ROOT"/*.zip
```
Replit zips sometimes nest everything inside a subdirectory. If `replit-source/` contains a single folder with all the files inside it, move everything up:
```bash
mv "$REPO_ROOT/replit-source"/<nested-folder>/* "$REPO_ROOT/replit-source"/<nested-folder>/.* "$REPO_ROOT/replit-source"/ 2>/dev/null
rmdir "$REPO_ROOT/replit-source"/<nested-folder>
```

**If you're in a worktree**, copy the extracted source into your worktree after extraction so you can work with it:
```bash
cp -a "$REPO_ROOT/replit-source" ./replit-source
```

**If the Replit project is already synced with GitHub:**
Ask the user for the repo name and clone it directly into the repo root:
```bash
git clone https://github.com/<owner>/<repo>.git "$REPO_ROOT/replit-source"
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

### Step M2: Explore and Discover

Read through the code (in `replit-source/` or the project root) to understand:
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

### Step M3: Provision Infrastructure

Use the same provisioning steps as a new project (Step 4 above), but:
- Create the GitHub repo with `infra/github-setup.sh` (if not already created in M1)
- Create Railway project with appropriate services based on what you discovered
- If Auth0: create new Auth0 app OR ask user to update existing callback URLs

### Step M4: Adapt the Code

**If code is in `replit-source/`:**

**CRITICAL: Delete blank-slate scaffolding BEFORE moving user code into the project root.** The scaffolding `templates/` directory will collide with Flask's `templates/` directory (or similar app directories). Delete scaffolding first, then move user code.

```bash
# 1. Read/save anything you need from scaffolding templates (Dockerfile template,
#    railway.json, storage abstraction, etc.) into memory BEFORE deleting.
# 2. Delete scaffolding directories
rm -rf infra/ templates/ migrate/ docs/ BLANK_SLATE_PLAN.md
# 3. Copy ALL user code from replit-source/ into project root
cp -a replit-source/* replit-source/.* . 2>/dev/null
# 4. Remove ONLY known Replit-specific files
rm -f .replit replit.nix replit-deploy.json .replit.deploy repl.deploy replit.md
rm -rf __pycache__ .cache .upm
```

**IMPORTANT: Copy EVERYTHING from `replit-source/`, then remove only the known Replit files listed above.** Do NOT cherry-pick which files to copy — you will miss things (notes, docs, reference images, config files, etc. that you didn't read). The user's project may contain files you don't know about. Copy all, remove only what's explicitly Replit-specific.

**If code is already in the root** (agency assembled it):

Just remove the Replit-specific files:
```bash
rm -f .replit replit.nix replit-deploy.json .replit.deploy repl.deploy replit.md
rm -rf __pycache__ .cache .upm
```

**Then for either case**, make these changes:
- **Replace Replit Object Storage** (if used) with the storage abstraction from `templates/app-stubs/python/storage/` (or Node equivalent). Update imports throughout the code.
- **Create `Dockerfile`** — based on the appropriate template, add any system dependencies found in `replit.nix` (e.g. ffmpeg, Playwright chromium deps)
- **Create `railway.json`** from templates
- **Create `start.sh`** if needed
- **Update `.gitignore`** — merge the imported project's gitignore with blank-slate's
- **Fix the dev port** — Replit apps typically default to port 5000, which conflicts with AirPlay Receiver on macOS. Change the local dev fallback to 8080 (e.g. `os.environ.get("PORT", 8080)`). Railway sets `PORT` automatically in production, so this only affects local dev.
- **Add `/health` endpoint** if not present
- **Preserve the app code** — don't restructure or refactor the user's code. Just make the minimal changes needed to run on Railway.

**Do NOT delete `replit-source/` yet** (if it exists). Keep it as a backup until everything is committed and verified working.

### Step M5: Handle Data Migration

Walk the user through these (they run the commands — Claude never sees credentials):

1. **Database:** Generate `pg_dump | pg_restore` commands. See `migrate/migrate-database.sh` (if still present) or use the patterns directly.
2. **Secrets:** List the env var names the app needs (from reading the code). Generate `railway variable set 'KEY=<value>'` commands for the user to fill in and run.
3. **Blob storage:** If the app used Replit Object Storage, walk through the storage migration flow — add temporary migration endpoints, set MIGRATION_SECRET, run script on Replit. See `migrate/README.md` or `migrate/migrate-storage.py` for the pattern.
4. **Auth0 callbacks:** If Auth0, tell user to add new Railway domain to callback/logout/origins URLs (keep old URLs until confirmed working).

### Step M6: Finalize

1. Handle CLAUDE.md:
   - If a project CLAUDE.md exists (from the imported code): append standard sections from `infra/claude-md-sections.md`
   - If no project CLAUDE.md: write one with project description + standard sections
2. Create `project.json`
3. Delete scaffolding: `rm -rf infra/ templates/ migrate/ docs/ BLANK_SLATE_PLAN.md`
4. Commit, push, set up Railway GitHub link (manual step)
5. Verify `/health` endpoint
6. **Only after everything is verified:** `rm -rf replit-source/` (if it exists)

---

## Existing Repo Flow

For repos that already have code (and possibly their own CLAUDE.md, .gitignore, CI workflows, Dockerfile, etc.) and want blank-slate's infrastructure provisioning added.

### Step E1: Explore the Existing Code

Read the codebase to understand:
- **Stack:** Language, framework, entry point
- **Database:** What's used, how it connects
- **Auth:** Existing auth setup
- **Existing deployment config:** Dockerfile? railway.json? CI workflows?
- **Existing CLAUDE.md:** What's in it? (Don't overwrite!)
- **Entry point / start command:** How does the app run?

### Step E2: Determine What's Needed

Present findings and ask what to provision:
- **Railway project** — with Postgres? Volume?
- **GitHub repo** — does one already exist? (Check `git remote -v`)
- **Auth0** — new app or update existing?
- **Custom domain** — suggest `<project>.jimmys.dev`
- **Auto-PR workflow** — skip if they already have CI, or ask if they want it
- **Dockerfile** — only if one doesn't exist
- **`/health` endpoint** — add if missing

### Step E3: Provision Infrastructure

Same scripts as other flows:
1. `bash infra/credential-check.sh railway`
2. `bash infra/credential-check.sh github`
3. `bash infra/github-setup.sh --name <name> --owner JimmysDev` (skip if repo exists)
4. `bash infra/railway-setup.sh --name <name> [--postgres] [--volume /data] [--domain <domain>]`
5. If auth needed: `bash infra/credential-check.sh auth0` then `bash infra/auth0-setup.sh`
6. If custom domain: `bash infra/credential-check.sh dns`

### Step E4: Add Deployment Files

**Only add what's missing — never overwrite existing files:**
- `Dockerfile` — create from template only if one doesn't exist
- `railway.json` — create only if one doesn't exist
- `.github/workflows/auto-pr.yml` — only if no existing CI workflows, or ask
- `start.sh` — only if needed and doesn't exist
- `storage/filesystem.py` — only if they need file storage and don't have an abstraction
- `/health` endpoint — add to the app if not present

### Step E5: Finalize

1. Append standard sections to existing CLAUDE.md from `infra/claude-md-sections.md`. If no CLAUDE.md exists, create one with project description + standard sections.
2. Create `project.json`
3. Delete scaffolding: `rm -rf infra/ templates/ migrate/ docs/ BLANK_SLATE_PLAN.md`
4. Commit, push
5. **ONE MANUAL STEP:** Connect GitHub repo in Railway dashboard
6. Verify `/health` endpoint

---

## Shared Reference

### Progressive Credential Model

Only check credentials for services actually needed:

| Tier | Service | When | Check |
|------|---------|------|-------|
| 1 | Railway CLI | Always | `railway whoami` |
| 1 | GitHub CLI | Always | `gh auth status` |
| 2 | Auth0 CLI | Auth needed | `auth0 tenants list` |
| 3 | GoDaddy API | Custom domain | `GODADDY_KEY` env var |
| 4 | Tailscale | SSH access | `tailscale status` |
| 5 | pg_dump | DB migration | `/opt/homebrew/opt/libpq/bin/pg_dump --version` |

### Secret Handling — CRITICAL

Claude must NEVER see secret values. Pattern:
- Generate commands for the user to run where secrets pipe directly from source to destination
- Verify by checking key names only: `railway variables --json | python3 -c "import sys,json; print(list(json.load(sys.stdin).keys()))"`
- Use single-quoted values with `railway variables --set 'KEY=value'` to avoid trailing newlines

### Railway CLI Gotchas

- `railway variables --set` adds trailing newline to values — always single-quote: `'KEY=value'`
- Env vars set via CLI only take effect on NEXT deploy — run `railway redeploy --service <name> --yes` after
- Always pass `--service <name>` to avoid interactive prompts
- `railway redeploy` requires `--yes` in non-interactive mode
- Docker builds take 3-7 min — poll `/health` after deploy, don't assume it's ready
- GitHub repo linking CANNOT be done via CLI — one manual dashboard step
- Railway Volumes persist across deploys — `/data` is the default mount point

### Port Conflicts

- macOS AirPlay Receiver uses port 5000. Replit apps often default to 5000.
- Default local dev port to 8080 (e.g. `os.environ.get("PORT", 8080)`)
- Railway sets `PORT` automatically in production — this only affects local dev

### Local Dev with Tailscale

- Mac hostname on tailnet: `jimmys-mac-mini`
- Access local dev server from phone: `http://jimmys-mac-mini:<port>`
- Tailscale must be running on both devices
