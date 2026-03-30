# Architecture: blank-slate

## Overview

blank-slate is an infrastructure plugin for projects. It provides scripts, templates, and a Claude Code skill (`/blank-slate-setup`) that provisions Railway deployments, GitHub repos, Auth0 apps, and DNS records.

It's a distribution repo — not a template you clone. Agency (or a user) copies blank-slate's files into any project, and the skill handles provisioning. After setup, the scaffolding is deleted, leaving only the app code and deployment config.

## How It Works

### Entry Point

The `/blank-slate-setup` skill (`.claude/commands/blank-slate-setup.md`) is the entry point. It:
1. Detects the repo state (empty, has Replit code, has existing code)
2. Reads `infra/SETUP.md` for the full provisioning instructions
3. Routes to the appropriate flow

### Three Flows

**New Project:** Empty repo → ask what to build → scaffold code + provision infrastructure → deploy.

**Replit Import:** Replit code is in the repo (agency put it there, or user extracted zip into `replit-source/`) → explore → provision → adapt code (strip Replit files, add Dockerfile, fix ports) → migrate data → deploy.

**Existing Repo:** Code is already here with its own CLAUDE.md → explore → provision → add only missing deployment files → append standard sections to CLAUDE.md → deploy.

### Distribution Model

The blank-slate repo (`JimmysDev/blank-slate`, private) is the source of truth. It holds:
- `.claude/commands/blank-slate-setup.md` — the skill file
- `CLAUDE.md` — pulled into projects that don't have one
- `infra/` — setup instructions + scripts
- `templates/` — Dockerfiles, railway.json, start.sh, app stubs
- `migrate/` — Replit migration guides and scripts

**pixel-agency** maintains a local copy. When creating a project:
- Agency creates the project directory
- Copies in blank-slate files (skill, infra/, templates/, etc.)
- If importing: gets the user's code into the root first
- Launches Claude — user runs `/blank-slate-setup`

**Solo use:** Clone blank-slate directly for a new project, or copy the skill + infra files into an existing repo.

### Script Design

All infrastructure scripts follow the same contract:
- **Non-interactive:** All config via flags, no `read` prompts
- **JSON output:** Every step emits JSON so Claude can parse results
- **Idempotent:** Check if resource exists before creating
- **Fail gracefully:** Warn on non-critical failures, error on blocking ones

### Self-Destructing Scaffolding

After setup completes, these are deleted:
- `infra/` — setup instructions + provisioning scripts
- `templates/` — Dockerfiles and app stubs (already copied to root)
- `migrate/` — migration tools
- `docs/` — this architecture doc

What remains:
- `CLAUDE.md` — with project-specific info + standard sections
- `project.json` — project config and setup marker
- `.github/workflows/auto-pr.yml` — CI/CD workflow
- App code, Dockerfile, railway.json

### CLAUDE.md Handling

- **New project (no existing CLAUDE.md):** The full blank-slate CLAUDE.md is used as-is, then updated with project info after provisioning.
- **Existing project (has CLAUDE.md):** Standard sections from `infra/claude-md-sections.md` are appended. The existing content is never overwritten.

### Secret Handling

Claude never sees secret values. The pattern:
1. Scripts output env var commands for the user to run
2. Verification checks key names only, never values
3. Migration uses temporary `MIGRATION_SECRET` endpoint pattern

### Railway Auto-Deploy

```
Push branch → GitHub Action creates PR → squash-merges to main → Railway detects main update → builds Docker → deploys
```

One manual step: connecting the GitHub repo in Railway's dashboard (Settings → Source).

## Directory Structure

```
blank-slate/
├── CLAUDE.md                              # Standard project CLAUDE.md (thin — points to infra/SETUP.md)
├── README.md
├── BLANK_SLATE_PLAN.md                    # Design document (V1 + V2)
├── .gitignore
├── .claude/
│   ├── settings.json
│   └── commands/
│       ├── blank-slate-setup.md           # Main entry point skill
│       └── hi-claude.md                   # Redirect to /blank-slate-setup
├── .github/
│   └── workflows/
│       └── auto-pr.yml
├── infra/
│   ├── SETUP.md                           # Full provisioning instructions (all 3 flows)
│   ├── claude-md-sections.md              # Appendable standard sections
│   ├── credential-check.sh
│   ├── railway-setup.sh
│   ├── github-setup.sh
│   └── auth0-setup.sh
├── templates/
│   ├── Dockerfile.python
│   ├── Dockerfile.node
│   ├── railway.json
│   ├── start.sh
│   └── app-stubs/
│       ├── python/ (app.py, requirements.txt, storage/filesystem.py)
│       └── node/ (index.js, package.json, storage/filesystem.js)
├── migrate/
│   ├── README.md
│   ├── migrate-database.sh
│   └── migrate-storage.py
└── docs/
    └── ARCHITECTURE.md
```
