#!/usr/bin/env bash
# =============================================================================
# github-setup.sh — Non-interactive GitHub repo creation and configuration
#
# Creates a GitHub repo (if it doesn't exist), sets workflow permissions,
# and enables auto-delete head branches.
#
# Usage:
#   bash infra/github-setup.sh --name my-project --owner JimmysDev
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# JSON output helpers
# ---------------------------------------------------------------------------
json_step() {
    local step="$1" status="$2" message="$3"
    echo "{\"step\":\"$step\",\"status\":\"$status\",\"message\":\"$message\"}"
}

json_error() {
    local step="$1" message="$2"
    echo "{\"step\":\"$step\",\"status\":\"error\",\"message\":\"$message\"}" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
REPO_NAME=""
OWNER=""
PRIVATE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)     REPO_NAME="$2"; shift 2 ;;
        --owner)    OWNER="$2"; shift 2 ;;
        --public)   PRIVATE=false; shift ;;
        -h|--help)
            echo "Usage: $0 --name REPO_NAME --owner OWNER [--public]"
            exit 0 ;;
        *) json_error "args" "Unknown argument: $1" ;;
    esac
done

if [[ -z "$REPO_NAME" || -z "$OWNER" ]]; then
    json_error "args" "Both --name and --owner are required"
fi

FULL_REPO="$OWNER/$REPO_NAME"

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------
if ! command -v gh &>/dev/null; then
    json_error "prereq" "GitHub CLI not installed. Run: brew install gh && gh auth login"
fi
if ! gh auth status &>/dev/null; then
    json_error "prereq" "Not logged in to GitHub. Run: gh auth login"
fi

# ---------------------------------------------------------------------------
# Step 1: Create repo if it doesn't exist
# ---------------------------------------------------------------------------
if gh repo view "$FULL_REPO" &>/dev/null; then
    json_step "create_repo" "skipped" "Repository already exists: $FULL_REPO"
else
    VISIBILITY="--private"
    [[ "$PRIVATE" == false ]] && VISIBILITY="--public"
    gh repo create "$FULL_REPO" $VISIBILITY --source=. --remote=origin --push 2>/dev/null && \
        json_step "create_repo" "ok" "Created repository: $FULL_REPO" || \
        json_error "create_repo" "Failed to create repository: $FULL_REPO"
fi

# ---------------------------------------------------------------------------
# Step 2: Set workflow permissions (write access + PR approval)
# ---------------------------------------------------------------------------
gh api "repos/$FULL_REPO/actions/permissions/workflow" \
    -X PUT \
    -f default_workflow_permissions=write \
    -F can_approve_pull_request_reviews=true 2>/dev/null && \
    json_step "workflow_permissions" "ok" "Workflow permissions set: write + PR approval" || \
    json_step "workflow_permissions" "warn" "Could not set workflow permissions — set manually in repo Settings → Actions"

# ---------------------------------------------------------------------------
# Step 3: Enable auto-delete head branches
# ---------------------------------------------------------------------------
gh api "repos/$FULL_REPO" \
    -X PATCH \
    -F delete_branch_on_merge=true 2>/dev/null && \
    json_step "auto_delete_branches" "ok" "Auto-delete head branches enabled" || \
    json_step "auto_delete_branches" "warn" "Could not enable auto-delete — set manually in repo Settings"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "{"
echo "  \"summary\": {"
echo "    \"repo\": \"$FULL_REPO\","
echo "    \"url\": \"https://github.com/$FULL_REPO\","
echo "    \"private\": $PRIVATE"
echo "  }"
echo "}"
