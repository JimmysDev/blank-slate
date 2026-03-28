# blank-slate

Railway-first project scaffolding template. Clone it, run `/hi-claude`, describe what you want to build, and Claude provisions everything.

## Quick Start

```bash
# Clone into a new project directory
git clone https://github.com/JimmysDev/blank-slate.git my-new-project
cd my-new-project

# Open Claude Code and run:
/hi-claude I want to build a podcast app with user accounts and file uploads
```

Claude will:
1. Ask clarifying questions about your stack and requirements
2. Create a Railway project with the right services (Postgres, Volume, etc.)
3. Create a GitHub repo and wire up auto-deploy
4. Set up Auth0 if you need authentication
5. Configure your custom domain
6. Deploy and verify your `/health` endpoint is live

## What You Need

First time only (~5 min):
- [Railway CLI](https://docs.railway.com/guides/cli): `brew install railway && railway login`
- [GitHub CLI](https://cli.github.com): `brew install gh && gh auth login`
- Optional: [Auth0 CLI](https://github.com/auth0/auth0-cli): `brew install auth0 && auth0 login`

Returning users: credentials persist, zero friction.

## How It Works

The `infra/` directory contains non-interactive scripts that Claude orchestrates:
- `credential-check.sh` — verifies you're logged in to each service
- `railway-setup.sh` — creates Railway project, DB, volume, domain
- `github-setup.sh` — creates repo, sets permissions
- `auth0-setup.sh` — creates Auth0 app (optional)

After setup, scaffolding directories (`infra/`, `templates/`, `migrate/`, `docs/`) are deleted. Only your app code remains.

## Migrating from Replit?

Mention "migrate" or "Replit" when talking to Claude. It will:
- Add the Railway filesystem storage abstraction (drop-in replacement for Replit Object Storage)
- Generate `pg_dump`/`pg_restore` commands for your database
- Help transfer blob storage via temporary authenticated endpoints
- Update Auth0 callback URLs

See `migrate/README.md` for details.
