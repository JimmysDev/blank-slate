# Architecture: blank-slate

## Overview

blank-slate is a self-destructing scaffolding template. It provisions a Railway-first project via Claude Code, then removes itself — leaving only the app code and deployment config.

## How It Works

### State Detection

`CLAUDE.md` instructs the agent to check repo state on every session:

- `infra/` exists + no `project.json` → unconfigured, run setup flow
- `project.json` exists → configured project, work normally

### Entry Point

User runs `/hi-claude` (defined in `.claude/commands/hi-claude.md`). Claude asks what they want to build, infers requirements, presents a plan, and provisions progressively.

### Provisioning Flow

```
/hi-claude "I want to build X"
    │
    ├── 1. credential-check.sh railway ──► installed? logged in?
    ├── 2. credential-check.sh github  ──► installed? logged in?
    │
    ├── 3. github-setup.sh ──► create repo, set permissions
    ├── 4. railway-setup.sh ──► create project, DB, volume, domain
    │
    ├── 5. Copy templates into project root
    │       Dockerfile, railway.json, start.sh, app stubs
    │
    ├── 6. (optional) credential-check.sh auth0
    │       auth0-setup.sh ──► create app, output env var commands
    │
    ├── 7. Rewrite CLAUDE.md (remove setup instructions)
    ├── 8. Create project.json (setup marker + config)
    ├── 9. Delete scaffolding (infra/, templates/, migrate/, docs/)
    │
    ├── 10. Commit + push → GitHub Action auto-merges to main
    ├── 11. User manually connects GitHub repo in Railway dashboard
    └── 12. Poll /health until deployed
```

### Script Design Principles

All infrastructure scripts follow the same contract:

- **Non-interactive:** All config via flags, no `read` prompts
- **JSON output:** Every step emits a JSON line so Claude can parse results
- **Idempotent:** Check if resource exists before creating
- **Fail gracefully:** Warn on non-critical failures, error on blocking ones

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

### Self-Destructing Scaffolding

After setup completes, these directories are deleted:
- `infra/` — provisioning scripts (no longer needed)
- `templates/` — Dockerfiles and app stubs (already copied to root)
- `migrate/` — migration tools (use only if migrating from Replit)
- `docs/` — this architecture doc (setup-time reference only)

What remains:
- `CLAUDE.md` — rewritten with project-specific instructions
- `project.json` — project config and setup marker
- `.github/workflows/auto-pr.yml` — CI/CD workflow
- App code, Dockerfile, railway.json

### Secret Handling

Claude never sees secret values. The pattern:
1. Scripts output env var commands for the user to run
2. Verification checks key names only, never values
3. Migration uses temporary `MIGRATION_SECRET` endpoint pattern

### Railway Auto-Deploy

```
Push branch → GitHub Action creates PR → squash-merges to main → Railway detects main update → builds Docker image → deploys
```

The one manual step: connecting the GitHub repo in Railway's dashboard (Settings → Source). This cannot be automated via CLI.

## Directory Structure (pre-setup)

```
blank-slate/
├── CLAUDE.md                    # Agent instructions (setup + project mode)
├── README.md                    # Human-facing overview
├── BLANK_SLATE_PLAN.md          # Design document
├── .gitignore
├── .claude/
│   ├── settings.json            # Tool permissions
│   └── commands/
│       └── hi-claude.md         # /hi-claude entry point
├── .github/
│   └── workflows/
│       └── auto-pr.yml          # Auto-create + squash-merge PRs
├── infra/
│   ├── credential-check.sh      # Progressive credential verification
│   ├── railway-setup.sh         # Railway provisioning
│   ├── github-setup.sh          # GitHub repo setup
│   └── auth0-setup.sh           # Auth0 app creation
├── templates/
│   ├── Dockerfile.python        # Python 3.12-slim
│   ├── Dockerfile.node          # Node 20-slim
│   ├── railway.json             # Railway build config
│   ├── start.sh                 # Container entrypoint
│   └── app-stubs/
│       ├── python/
│       │   ├── app.py
│       │   ├── requirements.txt
│       │   └── storage/
│       │       └── filesystem.py
│       └── node/
│           ├── index.js
│           ├── package.json
│           └── storage/
│               └── filesystem.js
├── migrate/
│   ├── README.md                # Migration guide
│   ├── migrate-database.sh      # pg_dump/pg_restore wrapper
│   └── migrate-storage.py       # Replit Object Storage → Railway
└── docs/
    └── ARCHITECTURE.md          # This file
```
