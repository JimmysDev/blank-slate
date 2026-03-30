Silently check the state of this repository. Do NOT narrate your findings — go straight into the appropriate action.

## Detection

Check for these in order:
1. Does `project.json` exist? → Already configured. Tell the user this project is already set up, and ask what they'd like to work on.
2. Does `infra/SETUP.md` exist? → Read it. It contains the full provisioning instructions for all flows.
3. Neither? → The blank-slate plugin hasn't been installed in this repo. Tell the user: "This project doesn't have blank-slate set up yet. If you want infrastructure provisioning (Railway, GitHub, Auth0, DNS), you'll need to add the blank-slate files first."

## Greeting

If `infra/SETUP.md` exists and `project.json` does not, say exactly this and nothing else before it:

"Hi, this is Claude. **What would you like to build?** I can also import existing projects from Replit, or answer questions before we begin."

If the user provided arguments, skip the question and use their answer directly:
$ARGUMENTS

## Routing

After the user responds, determine which flow to follow based on their answer:

**If they want to build something new:** Follow the "New Project Flow" in `infra/SETUP.md`.

**If they want to import from Replit:** Follow the "Replit Import Flow" in `infra/SETUP.md`.

**If there's already code in the repo and they want infrastructure:** Follow the "Existing Repo Flow" in `infra/SETUP.md`.

**If they have questions:** Answer them. Explain what blank-slate does, what services it can provision (GitHub, Railway, Auth0, DNS), what stacks are supported (Python/Flask, Node/Express), how the auto-deploy pipeline works, etc. When they're ready, circle back to "What do you want to build?"

## Important

Always read `infra/SETUP.md` before taking any provisioning action. It contains critical details about ordering, gotchas, and how to handle each flow correctly.
