# blank-slate

Railway infrastructure plugin for projects. Add it to any repo to get automated provisioning of Railway deployments, GitHub repos, Auth0 apps, and custom domains.

## Quick Start

### New Project (solo)

```bash
git clone git@github.com:JimmysDev/blank-slate.git my-new-project
cd my-new-project
# Open Claude Code, then:
/blank-slate-setup I want to build a podcast app with user accounts
```

### With pixel-agency

Agency handles setup — creates the project directory, copies in blank-slate files, and optionally imports your existing code. Then just run `/blank-slate-setup`.

### Existing Repo

Copy `.claude/commands/blank-slate-setup.md` and the `infra/` directory into your repo, then run `/blank-slate-setup`.

## What It Provisions

- **GitHub repo** with auto-merge CI (push → PR → squash-merge → deploy)
- **Railway project** with Postgres, persistent volume, custom domain
- **Auth0** app with callback URLs (optional)
- **Dockerfile + deployment config** (Python/Flask or Node/Express)
- **DNS** via GoDaddy API (optional)

## What You Need

First time only (~5 min):
- [Railway CLI](https://docs.railway.com/guides/cli): `brew install railway && railway login`
- [GitHub CLI](https://cli.github.com): `brew install gh && gh auth login`
- Optional: [Auth0 CLI](https://github.com/auth0/auth0-cli): `brew install auth0 && auth0 login`

## How It Works

The `/blank-slate-setup` skill reads `infra/SETUP.md` and orchestrates non-interactive scripts:
- `infra/credential-check.sh` — verifies CLI auth
- `infra/railway-setup.sh` — creates Railway project, DB, volume, domain
- `infra/github-setup.sh` — creates repo, sets permissions
- `infra/auth0-setup.sh` — creates Auth0 app (optional)

After setup, scaffolding (`infra/`, `templates/`, `migrate/`, `docs/`) is deleted. Only app code and deployment config remain.

## Migrating from Replit?

The Replit import flow handles everything: code, database, blob storage, secrets, Auth0 callbacks. See `infra/SETUP.md` for the full flow, or just run `/blank-slate-setup` and say "import from Replit."
