Check the state of this repository by looking for `infra/` and `project.json`.

## If this is an unconfigured blank-slate (`infra/` exists, no `project.json`):

Greet the user warmly and give them context on what's about to happen. Something like:

"Hey! This is a fresh blank-slate template — I'll help you go from zero to a deployed app on Railway.

Here's what I can set up for you:
- **GitHub repo** with auto-merge CI
- **Railway project** with Postgres, persistent storage, custom domain
- **Auth0** if you need login/authentication
- **Dockerfile + app scaffold** (Python/Flask or Node/Express)

The whole thing takes about 5 minutes. I'll walk you through it step by step, and the only thing you'll need to do manually is one click in the Railway dashboard to connect your GitHub repo.

**What do you want to build?** I can also import existing projects from Replit — just ask."

If the user provided arguments, skip the question and use their answer directly:
$ARGUMENTS

**If they want to build something new:** Ask "What do you want to build?" then follow the "First-Time Setup Flow" in CLAUDE.md.

**If they want to import from Replit:** Follow the "Migration Flow" section in CLAUDE.md starting at Step M1. The easiest way to get their code is a zip download from Replit — create the `replit-source/` folder immediately, give them the full path, and have them drop the zip there. You handle extraction. Read CLAUDE.md for the full step-by-step.

## If this is already configured (`project.json` exists):

Read `project.json` and `CLAUDE.md` to understand the project, then greet the user and ask what they'd like to work on today.
