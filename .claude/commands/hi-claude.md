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

**If they want to import from Replit:** Follow the "Migration Flow" section in CLAUDE.md. The first thing to figure out is how to get their code — push from Replit's shell to GitHub (preferred) or download as zip. Their code goes into `replit-source/` in this directory, never directly in the root. You'll explore it, discover the stack/DB/auth/storage, provision infrastructure, adapt the code, and clean up so the final repo looks like it was always a blank-slate project.

## If this is already configured (`project.json` exists):

Read `project.json` and `CLAUDE.md` to understand the project, then greet the user and ask what they'd like to work on today.
