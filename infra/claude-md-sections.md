# Standard CLAUDE.md Sections

These sections should be appended to a project's CLAUDE.md after provisioning. Copy everything below the line.

---

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

## Railway-Managed Files

The following files are managed by Railway deployment and should only be modified intentionally:
- `Dockerfile` — container build instructions
- `railway.json` — Railway build and deploy config

## Railway CLI Gotchas

- `railway variables --set` adds trailing newline to values — always single-quote: `'KEY=value'`
- Env vars set via CLI only take effect on NEXT deploy — run `railway redeploy --service <name> --yes` after
- Always pass `--service <name>` to avoid interactive prompts
- `railway redeploy` requires `--yes` in non-interactive mode
- Docker builds take 3-7 min — poll `/health` after deploy, don't assume it's ready
- GitHub repo linking CANNOT be done via CLI — one manual dashboard step
- Railway Volumes persist across deploys — `/data` is the default mount point

## Local Dev with Tailscale

Tailscale makes the local dev server accessible from any device on the tailnet (phone, other computers).

- Mac hostname on tailnet: `jimmys-mac-mini`
- Access local dev server from phone: `http://jimmys-mac-mini:<port>` (e.g. `:8080` for Flask)
- Tailscale must be running on both the Mac and the accessing device
