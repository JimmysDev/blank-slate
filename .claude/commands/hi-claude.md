Silently check the state of this repository by looking for `infra/` and `project.json`. Do NOT narrate the state detection to the user (don't say things like "infra/ exists and there's no project.json"). Just go straight into the appropriate greeting.

## If this is an unconfigured blank-slate (`infra/` exists, no `project.json`):

Say exactly this and nothing else before it:

"**What do you want to build?** I can also import existing projects from Replit, or answer questions before we begin building."

If the user provided arguments, skip the question and use their answer directly:
$ARGUMENTS

**If they want to build something new:** Follow the "First-Time Setup Flow" in CLAUDE.md — determine requirements from their answer, present a plan, get confirmation, provision.

**If they want to import from Replit:** Follow the "Migration Flow" section in CLAUDE.md starting at Step M1. The easiest way to get their code is a zip download from Replit — create the `replit-source/` folder immediately, give them the full path, and have them drop the zip there. You handle extraction. Read CLAUDE.md for the full step-by-step.

**If they have questions:** Answer them. Explain what blank-slate does, what services it provisions (GitHub, Railway, Auth0, DNS), what stacks are supported (Python/Flask, Node/Express), how the auto-deploy pipeline works, etc. When they're ready to start, circle back to "What do you want to build?"

## If this is already configured (`project.json` exists):

Read `project.json` and `CLAUDE.md` to understand the project, then greet the user and ask what they'd like to work on today.
