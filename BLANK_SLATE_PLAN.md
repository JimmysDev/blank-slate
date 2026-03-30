# Blank-Slate: Railway Infrastructure Plugin

## V2 Design Direction (agreed March 2026)

### The Shift

blank-slate started as a template repo you clone. That works for "start from scratch" but breaks down for every other scenario — importing from Replit means cramming code into blank-slate's repo, existing repos conflict with blank-slate's CLAUDE.md, etc.

**New model:** blank-slate is a **plugin**, not a template. It's a distribution repo that holds infrastructure scripts, templates, migration guides, and a skill file. It's never the foundation of your project — your project is the foundation, and blank-slate's capabilities get layered on.

### How It Works

**The skill is `/blank-slate-setup`.** It lives at `.claude/commands/blank-slate-setup.md`. When invoked, it:

1. Checks if infra scripts are local — if not, copies them from blank-slate's distribution
2. Checks if there's a CLAUDE.md — if not, pulls blank-slate's full version. If yes, leaves it alone (appends infrastructure sections at the end after provisioning)
3. Reads the existing codebase to understand what's there
4. Asks what needs provisioning (or infers from context)
5. Runs the infra scripts (Railway, GitHub, Auth0, DNS)
6. Adds deployment files (Dockerfile, railway.json, auto-pr.yml) — only what's missing
7. Cleans up scaffolding, appends standard sections to CLAUDE.md, creates project.json

### Distribution

The blank-slate repo (`JimmysDev/blank-slate`, private) is the source of truth. It holds:
- `.claude/commands/blank-slate-setup.md` — the skill file
- `CLAUDE.md` — pulled into projects that don't have one
- `infra/` — scripts (credential-check, railway-setup, github-setup, auth0-setup)
- `templates/` — Dockerfiles, railway.json, start.sh, app stubs, storage abstraction
- `migrate/` — Replit migration guides and scripts

**pixel-agency** maintains a local copy of blank-slate (cloned or periodically pulled). When creating a project:
- Agency creates the project directory
- If the user wants infrastructure: agency copies `.claude/commands/blank-slate-setup.md` (and optionally the full `infra/` + `templates/` dirs) into the project
- If importing from Replit: agency gets the code into the project root first (zip download, clone, etc.), then copies in blank-slate files
- If no infrastructure wanted: agency does nothing — blank-slate never enters the picture

**Solo use (no agency):** User clones blank-slate, copies the skill file into their project. Or for a new project, clones blank-slate directly (same as today's flow 1).

### The Four Flows — Unified

1. **New project (solo):** Clone blank-slate, run `/blank-slate-setup`, describe what you want. Full CLAUDE.md is already there. Provisions + scaffolds code.

2. **Import from Replit:** Project dir starts with the user's code (agency assembled it, or user dropped a zip). Blank-slate skill is in `.claude/commands/`. Run `/blank-slate-setup import from Replit`. Agent explores code, provisions infrastructure around it, strips Replit-specific files, handles data migration. No more `replit-source/` shuffle — the user's code IS the repo.

3. **Existing repo + wants infrastructure:** Code is already here with its own CLAUDE.md. Agency dropped in the skill. Run `/blank-slate-setup`. Agent explores, asks what to provision, layers infrastructure on top. Existing CLAUDE.md gets infrastructure sections appended, not replaced.

4. **Existing repo, no infrastructure:** blank-slate is never involved. Agency manages the project without it.

### Maintenance

- Push updates to `JimmysDev/blank-slate`
- Agency pulls latest periodically (on startup, on demand, etc.)
- Already-provisioned projects don't need updates — scripts are gone, CLAUDE.md sections are static
- Only the next project benefits from improvements

### What This Means for the Current Codebase

The existing scripts, templates, and migration tools are all still valid — they just get reorganized:
- The skill file (`/blank-slate-setup`) replaces `/hi-claude` as the entry point
- CLAUDE.md becomes a "full version" that gets pulled into empty projects, and a "sections to append" version for existing projects
- The `replit-source/` flow in CLAUDE.md gets simplified since agency handles getting code into the project root

### Open Questions

- Should `/blank-slate-setup` remain the name, or something shorter?
- How does agency signal to the skill what kind of setup is needed (new vs import vs existing)? Environment variable? A config file?
- Should the skill auto-detect the scenario, or always ask?

---
---

## V1 Design (original — implemented, being superseded by V2)

## Context

Jimmy has a template repo `JimmysDev/replit-blank-slate` that is Replit-centric. After migrating ttsCast from Replit to Railway, we need a new `JimmysDev/blank-slate` repo that is Railway-first. The ttsCast migration proved the workflow: Dockerfile, Railway Volume, filesystem storage abstraction, GitHub auto-deploy, Auth0, custom DNS. This plan creates the template that makes spinning up new projects (or migrating existing ones) a single-command experience.

**Goal:** Create `JimmysDev/blank-slate` — a template repo where you clone it, run `/hi-claude`, answer one question ("what do you want to build?"), and Claude provisions everything.

---

## Repo Structure

```
blank-slate/
├── CLAUDE.md                              # Agent instructions (detects setup state, drives provisioning)
├── README.md                              # Human-facing overview
├── .gitignore
├── .claude/
│   ├── settings.json                      # Tool permissions
│   └── commands/
│       └── hi-claude.md                   # /hi-claude slash command entry point
├── .github/
│   └── workflows/
│       └── auto-pr.yml                    # Auto-create PR, squash-merge (no deploy curl — Railway watches main)
├── infra/
│   ├── credential-check.sh               # Progressive credential verification
│   ├── railway-setup.sh                   # Railway provisioning (project, DB, volume, env, domain)
│   ├── github-setup.sh                    # GitHub repo creation + workflow permissions
│   └── auth0-setup.sh                     # Auth0 app creation (optional)
├── templates/
│   ├── Dockerfile.python                  # Python 3.12-slim + Railway Volume
│   ├── Dockerfile.node                    # Node 20-slim + Railway Volume
│   ├── railway.json                       # Railway build config
│   ├── start.sh                           # Entrypoint (optional Tailscale + exec app)
│   └── app-stubs/
│       ├── python/
│       │   ├── app.py                     # Minimal Flask with /health
│       │   ├── requirements.txt           # Flask, gunicorn, psycopg2-binary
│       │   └── storage/
│       │       └── filesystem.py          # Drop-in Replit Object Storage replacement (proven in ttsCast)
│       └── node/
│           ├── index.js                   # Minimal Express with /health
│           ├── package.json
│           └── storage/
│               └── filesystem.js          # Node equivalent
├── migrate/
│   ├── README.md                          # Migration flow overview
│   ├── migrate-database.sh               # pg_dump/pg_restore wrapper
│   └── migrate-storage.py                # Replit Object Storage → Railway Volume (proven in ttsCast)
└── docs/
    └── ARCHITECTURE.md                    # How blank-slate works
```

---

## UX Flow

### Entry Point

User clones blank-slate into a new directory, opens Claude Code, types `/hi-claude`.

### Detection Logic

CLAUDE.md tells the agent: if `infra/` directory exists AND `project.json` does NOT exist → this is an unconfigured blank-slate. Prompt the user.

### New Project Flow

**Step 1: Ask one question.** "What do you want to build?" Free-text answer.

**Step 2: Determine requirements from the answer.**
- Stack: Python (Flask) or Node (Express) — infer from description, ask if ambiguous
- Database: needed if description mentions storage, users, data, accounts
- Auth: needed if description mentions login, users, accounts, authentication
- File storage: needed if description mentions uploads, files, images, audio
- Custom domain: ask explicitly — suggest `<project>.jimmys.dev`

**Step 3: Present plan and confirm.** "I'll set up: Railway project with Postgres + Volume, GitHub repo, Auth0 app, domain at foo.jimmys.dev. Sound good?"

**Step 4: Progressive provisioning.** Only check credentials for services actually needed:
1. Check Railway CLI → if missing, give install command, wait
2. Check GitHub CLI → if missing, give install command, wait
3. Run `infra/github-setup.sh` (create repo, set permissions)
4. Run `infra/railway-setup.sh` (create project, add DB/volume if needed)
5. Copy template files (Dockerfile, railway.json, start.sh, app stub) into project root
6. If auth needed: check Auth0 CLI → run `infra/auth0-setup.sh`
7. If custom domain: run domain setup (GoDaddy for now, Cloudflare TODO)
8. Rewrite CLAUDE.md from setup-mode to project-mode (project-specific instructions)
9. Create `project.json` marker with all config
10. Delete scaffolding dirs (`infra/`, `templates/`, `migrate/`, `docs/`)
11. Initial commit + push → GH Action auto-merges → Railway auto-deploys
12. **ONE manual step:** User connects GitHub repo in Railway dashboard (Settings → Source). Print the exact URL.
13. Verify `/health` endpoint responds on deployed URL

**Step 5: Report success** with live links.

### Migration Flow (secondary)

When user mentions "migrate" or "Replit":
1. Don't scaffold new code — use their existing code
2. Add `storage/filesystem.py` if they used Replit Object Storage
3. Add Dockerfile and railway.json
4. Migrate database: generate `pg_dump | pg_restore` command for user to run
5. Migrate secrets: generate `railway variables --set` commands (user runs them — Claude never sees values)
6. Migrate storage: use `migrate/migrate-storage.py` with temporary MIGRATION_SECRET endpoints
7. Update Auth0 callback URLs for new domain

---

## Progressive Credential Model

**Principle:** No unnecessary logins. Only check what's needed, when it's needed.

| Tier | Service | When Needed | Check Command | Fix Command |
|------|---------|------------|---------------|-------------|
| 1 | Railway CLI | Always | `railway whoami` | `brew install railway && railway login` |
| 1 | GitHub CLI | Always | `gh auth status` | `brew install gh && gh auth login` |
| 2 | Auth0 CLI | Auth enabled | `auth0 tenants list` | `brew install auth0 && auth0 login` |
| 3 | DNS provider | Custom domain | Check `GODADDY_KEY` env var | GoDaddy developer portal |
| 4 | Tailscale | SSH access | `tailscale status` | `brew install tailscale` |
| 5 | pg_dump | DB migration | `/opt/homebrew/opt/libpq/bin/pg_dump --version` | `brew install libpq` |

**First-time:** User installs + auths 2 CLIs (~5 min). Claude says: "This is one-time — future projects will be instant."

**Returning user:** "Checking credentials... Railway: logged in. GitHub: logged in. Proceeding." (Zero friction.)

CLI creds persist in their standard locations (`~/.railway/`, `~/.config/gh/`, `~/.config/auth0/`).

---

## Script Specifications

### `infra/credential-check.sh`
- Takes one arg: service name (railway, github, auth0, dns, tailscale, pgdump)
- Exit 0 + JSON on success: `{"service":"railway","user":"jimmy@...","status":"ok"}`
- Exit 1 + human-readable fix instructions on failure
- Claude calls this before each provisioning step

### `infra/railway-setup.sh`
- Refactored from existing `/Users/jimmy/Documents/Coding/local-repos/replit-blank-slate/railway-setup.sh` (396 lines)
- Non-interactive — all flags explicit, no `read -rp` prompts
- Outputs JSON for every step so Claude can parse results
- Idempotent (checks if project exists before creating)
- Flags: `--name`, `--postgres`, `--volume <mount>`, `--domain <domain>`, `--env KEY=VALUE`, `--env-file <path>`
- Note: GitHub repo linking in Railway cannot be automated via CLI — prints instruction for the one manual step

### `infra/github-setup.sh`
- Creates repo if it doesn't exist: `gh repo create`
- Sets workflow permissions: write access, PR approval
- Enables auto-delete head branches
- Flags: `--name`, `--owner`

### `infra/auth0-setup.sh`
- Creates Auth0 app with proper callback URLs
- Sets Railway env vars (AUTH0_CLIENT_ID, AUTH0_CLIENT_SECRET, AUTH0_DOMAIN)
- Flags: `--name`, `--domain <app-url>`

### `.claude/commands/hi-claude.md`
- The `/hi-claude` slash command
- Instructs Claude to greet user, ask what they want to build, then follow CLAUDE.md setup instructions
- Captures inline arguments via `$ARGUMENTS`

---

## Key Source Files to Copy/Adapt

| What | Source | Destination |
|------|--------|-------------|
| Storage abstraction | `ttsCast-Core/storage/filesystem.py` | `templates/app-stubs/python/storage/filesystem.py` (verbatim) |
| Railway setup script | `replit-blank-slate/railway-setup.sh` | `infra/railway-setup.sh` (refactored: non-interactive, JSON output) |
| Auto-PR workflow | `ttsCast-Core/.github/workflows/auto-pr.yml` | `.github/workflows/auto-pr.yml` (strip deploy curl step) |
| Dockerfile pattern | `ttsCast-Core/Dockerfile` | `templates/Dockerfile.python` (generalized, no ttsCast-specific deps) |
| railway.json | `ttsCast-Core/railway.json` | `templates/railway.json` (verbatim) |
| Migration script | `ttsCast-Core/scripts/migrate_storage.py` | `migrate/migrate-storage.py` (generalized) |

---

## Secret Handling — CRITICAL

Claude must NEVER see secret values. Pattern:
- Generate commands for the user to run where secrets pipe directly from source to destination
- Verify by checking key names only: `railway variables --json | python3 -c "import sys,json; print(list(json.load(sys.stdin).keys()))"`
- Migration secrets use the MIGRATION_SECRET temporary endpoint pattern (proven in ttsCast)

---

## TODOs (defer — do not implement in v1)

- **Cloudflare DNS** — replace GoDaddy API. Add `--dns-provider cloudflare` flag stub.
- **Railway GitHub linking automation** — investigate Railway API for programmatic repo connection. For now: one manual dashboard step.
- **Tailscale in Dockerfile** — stub in `start.sh` but not fully tested in Railway containers.
- **Node.js storage abstraction** — `filesystem.js` needs to be written and tested.
- **Auth0 tenant rename** — replace ugly auto-generated tenant name.

---

## Implementation Sequence

An agent should follow this order, working in a new `blank-slate` repo:

**Phase 1 — Repo Foundation:**
1. Create the GitHub repo `JimmysDev/blank-slate`
2. `.gitignore`, `README.md`
3. `CLAUDE.md` (pre-setup version with full setup instructions)
4. `.claude/settings.json` (permissions for all infra scripts)
5. `.claude/commands/hi-claude.md`

**Phase 2 — Infrastructure Scripts:**
6. `infra/credential-check.sh`
7. `infra/railway-setup.sh` (refactor from replit-blank-slate)
8. `infra/github-setup.sh`
9. `infra/auth0-setup.sh`

**Phase 3 — Templates:**
10. `templates/Dockerfile.python` (generalize from ttsCast Dockerfile)
11. `templates/Dockerfile.node`
12. `templates/railway.json`
13. `templates/start.sh`
14. Python app stubs (`app.py`, `requirements.txt`, `storage/filesystem.py`)
15. Node app stubs (`index.js`, `package.json`, `storage/filesystem.js` placeholder)

**Phase 4 — CI/CD:**
16. `.github/workflows/auto-pr.yml` (from ttsCast, strip deploy curl)

**Phase 5 — Migration Support:**
17. `migrate/README.md` (migration flow)
18. `migrate/migrate-database.sh`
19. `migrate/migrate-storage.py` (generalize from ttsCast)

**Phase 6 — Documentation:**
20. `docs/ARCHITECTURE.md`

**Phase 7 — Verification:**
21. `chmod +x` all scripts
22. Test `credential-check.sh` locally
23. Commit and push to `JimmysDev/blank-slate`

---

## Design Decisions

**Why Claude drives the scripts:** Scripts are non-interactive, JSON-outputting tools that Claude orchestrates. The user experience is conversational, not shell-based.

**Why the template self-destructs:** After setup, `infra/`, `templates/`, `migrate/`, `docs/` are deleted. They're scaffolding, not app code. `project.json` prevents re-runs.

**Why auto-pr.yml has no deploy step:** Railway auto-deploys when main updates via GitHub integration. No webhook needed.

**Why one manual step survives:** Railway CLI cannot programmatically link a GitHub repo to a service. The user must click Settings → Source in the Railway dashboard once. Everything else is automated.

---

## Railway CLI Gotchas (learned the hard way during ttsCast migration)

These are verified behaviors that scripts MUST account for. Do not assume standard CLI conventions — Railway's CLI has quirks.

### Environment Variables

- **`railway variables --set` adds a trailing newline** to values. This silently breaks string comparisons (e.g. secret matching). Always verify with: `railway variables --service <name> --json 2>&1 | python3 -c "import sys,json; print(repr(json.load(sys.stdin).get('KEY')))"` and check for `\n`.
- **Workaround:** Use single-quoted values: `railway variables --set 'KEY=value'` (not double-quoted, not unquoted).
- **Env vars set via CLI don't take effect on the running deployment.** They only apply on the NEXT deploy. After setting vars, always trigger a redeploy: `railway redeploy --service <name> --yes`.
- **`railway variable` (singular) vs `railway variables` (plural)** are DIFFERENT commands with different subcommand structures. Use `railway variable delete --service <name> KEY` to delete. Use `railway variables --set 'KEY=value' --service <name>` to set (legacy syntax). The newer syntax is `railway variable set --service <name> KEY=value`.
- **`railway variables` without `--service` goes interactive** and hangs in non-interactive contexts. Always pass `--service <name>`.

### Deployments

- **`railway redeploy` requires `--yes`** in non-interactive mode. Without it, the command errors with "Cannot prompt for confirmation."
- **Docker builds take 3-7 minutes** depending on dependencies. Playwright/Chromium adds ~3 minutes. Poll the health endpoint after deploy rather than assuming it's ready.
- **Railway auto-deploys from GitHub** when the repo is linked (Settings → Source → Connect). Pushes to the configured branch (usually `main`) trigger a new build automatically. This means the GitHub Action auto-PR workflow (merge to main) is sufficient — no deploy webhook/curl needed.
- **The GitHub repo link CANNOT be done via CLI.** This is the one unavoidable manual step. The user must go to: `https://railway.com/project/<project-id>/service/<service-id>/settings` → Source → Connect `<owner>/<repo>` on branch `main`. The setup script should print this exact URL.

### Volumes

- **Railway Volumes persist across deploys** — files written to the mount point survive restarts and redeployments. This is unlike Replit's ephemeral filesystem.
- **Default Volume mount:** `/data` exists on Railway. The storage abstraction should default to `/data/storage` when `/data` is detected.

### Project/Service Naming

- **`railway status`** shows current linked project and service. Use this to verify context before running commands.
- **`railway link`** associates the current directory with a project. Run this after `railway init` if the CLI loses context.

---

## Storage Migration Gotchas (from ttsCast Replit → Railway migration)

### The Problem
Replit Object Storage is a proprietary blob store. Files stored there (audio, images, etc.) don't exist on Railway. The database migrates via pg_dump, but blob storage requires a separate transfer process.

### Migration Endpoint Pattern
The proven approach uses temporary authenticated endpoints on the Railway app:

1. **Add temporary endpoints** to the app code:
   - `POST /api/admin/storage-upload` — receives a blob, stores it
   - `HEAD /api/admin/storage-check/<key>` — checks if a key exists (for resume/skip)
   - `POST /api/admin/storage-delete` — deletes a blob by key
   - `GET /api/admin/storage-list` — lists all stored keys
2. **Protect with `MIGRATION_SECRET`** env var — checked via `X-Migration-Secret` header
3. **Run migration script on Replit** — lists Replit Object Storage, uploads each file to Railway
4. **Remove endpoints after migration** — delete the routes and the env var

### Critical Implementation Details

- **HTTP headers cannot carry non-ASCII characters.** Filenames with Unicode (curly quotes `'`, em-dashes `—`, etc.) must be URL-encoded in the `X-Storage-Key` header using `urllib.parse.quote(key, safe='')` on the client side and `urllib.parse.unquote()` on the server side. This was discovered after 20/100 files failed silently.
- **The migration script must be resumable.** Check if each key exists on the destination before uploading. The ttsCast migration timed out twice and needed to resume.
- **Replit Object Storage can have thousands of files** (ttsCast had 5,289). Migrating ALL of them may exceed volume limits. The `migrate-recent.py` pattern queries the DB for the N most recent entries and only migrates those, deleting everything else from the destination.
- **The migration script runs ON REPLIT** (where `from replit.object_storage import Client` works). It pushes TO Railway via HTTP. The reverse direction doesn't work because Railway can't import the Replit SDK.
- **Set MIGRATION_SECRET BEFORE deploying the migration endpoints.** If you deploy the code first and set the secret after, the running instance won't have the env var (see "env vars don't take effect" gotcha above). Deploy sequence: set env var → deploy code → verify endpoint → run migration.
- **Test the endpoint with a small payload first** before running the full migration. Verify the response includes the correctly decoded key.

### Database Migration

- **pg_dump/pg_restore** is the standard approach. On macOS, psql/pg_dump may not be in PATH: use `/opt/homebrew/opt/libpq/bin/pg_dump` and `/opt/homebrew/opt/libpq/bin/psql`.
- **DATABASE_URL format:** `postgresql://user:pass@host:port/dbname`. Railway provides this as a service variable. Replit stores it as a secret.
- **The `.env` file** at project root (gitignored) should contain `DATABASE_URL=...` for local access. Load with: `export $(grep DATABASE_URL .env)`.

---

## Auth0 Migration Gotchas

- **Callback URLs must be updated** when changing domains. Auth0 app settings → Allowed Callback URLs, Allowed Logout URLs, Allowed Web Origins. Add the new Railway domain alongside the old Replit domain (don't remove the old one until migration is confirmed working).
- **The Auth0 CLI (`auth0 apps update`)** can update callback URLs programmatically, but the CLI output format changed between versions. Always parse JSON output, don't rely on text patterns.
- **Session cookies from the old domain won't work** on the new domain. Users will need to log in again after the domain change.

---

## DNS & SSL Gotchas

- **Railway provides automatic SSL** for custom domains once DNS is pointed correctly. No manual cert provisioning needed.
- **CNAME records:** Point `<subdomain>.jimmys.dev` → `<project>.up.railway.app`. Use the Railway-provided CNAME target from `railway domain` output.
- **DNS propagation** can take minutes to hours. After setting the CNAME, poll with `dig <domain> +short` until it resolves.
- **GoDaddy API** for DNS automation requires API key + secret. These are stored as env vars (`GODADDY_KEY`, `GODADDY_SECRET`), not in any config file. TODO: switch to Cloudflare API which is more developer-friendly.

---

## GitHub Actions / CI/CD Gotchas

- **The auto-pr.yml workflow** triggers on push to any non-main branch. It creates a PR and immediately squash-merges it. This means: push a branch → PR created → merged to main → Railway auto-deploys. The entire cycle takes 1-3 minutes.
- **GitHub workflow permissions** must be set to "Read and write" with "Allow GitHub Actions to create and approve pull requests" enabled. Without this, the auto-PR workflow fails silently. Set via: `gh api repos/<owner>/<repo>/actions/permissions/workflow -X PUT -f default_workflow_permissions=write -F can_approve_pull_request_reviews=true`.
- **The old Replit deploy curl step** in the workflow is unnecessary on Railway. Railway watches the GitHub repo directly. Strip the "Trigger deploy" step from auto-pr.yml.
- **`DEPLOY_URL` and `DEPLOY_SECRET` GitHub secrets** from the Replit era should be removed or ignored. They pointed at the old Replit `/api/deploy` endpoint.

---

## Siri Shortcut / Mobile API Considerations

- **The ttsCast Siri Shortcut** sends full page HTML via JavaScript extraction (`document.documentElement.outerHTML`). This is slow on heavy pages and causes timeouts.
- **Better approach for new projects:** Have the Shortcut send just the URL. The server fetches and scrapes the page server-side. This makes the Shortcut near-instant and moves the heavy lifting to the server (which is async anyway).
- **The `/api/tts` endpoint** accepts JSON with `html` or `text` fields and an optional `user_email`. No authentication is required (it uses `@cross_origin()`). For new projects, consider adding API key auth.
- **Shortcut stores user email** in iCloud Drive at `/ttsCast/user.txt` — first run prompts for it, subsequent runs read from file. This pattern works well for per-user API access without auth tokens.

---

## Asset Seeding Pattern

When an app needs static assets in blob storage (logos, canned audio, etc.), use the startup seed pattern:

```python
def _seed_storage_assets(client):
    assets = {
        'logo.png': 'static/logo.png',  # storage_key: local_file_path
    }
    for storage_key, local_path in assets.items():
        if not client.exists(storage_key):
            full_path = os.path.join(os.path.dirname(__file__), local_path)
            if os.path.isfile(full_path):
                with open(full_path, 'rb') as f:
                    client.upload_from_bytes(storage_key, f.read())
```

This runs at app startup. Assets that must always be available should be committed to git in `static/` and seeded into storage on first deploy. This eliminates the need to manually upload files after a fresh deployment.
