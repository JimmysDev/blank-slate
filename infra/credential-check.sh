#!/usr/bin/env bash
# =============================================================================
# credential-check.sh — Progressive credential verification
#
# Checks if a specific service CLI is installed and authenticated.
# Exit 0 + JSON on success, exit 1 + human-readable fix on failure.
#
# Usage:
#   bash infra/credential-check.sh railway
#   bash infra/credential-check.sh github
#   bash infra/credential-check.sh auth0
#   bash infra/credential-check.sh dns
#   bash infra/credential-check.sh tailscale
#   bash infra/credential-check.sh pgdump
# =============================================================================

set -euo pipefail

SERVICE="${1:-}"

json_ok() {
    echo "{\"service\":\"$1\",\"user\":\"$2\",\"status\":\"ok\"}"
    exit 0
}

fail() {
    echo ""
    echo "=== $1 is not ready ==="
    echo ""
    echo "$2"
    echo ""
    exit 1
}

case "$SERVICE" in
    railway)
        if ! command -v railway &>/dev/null; then
            fail "Railway CLI" "Install with:
  brew install railway

Then log in:
  railway login"
        fi
        USER=$(railway whoami 2>/dev/null || true)
        if [[ -z "$USER" ]]; then
            fail "Railway CLI" "Not logged in. Run:
  railway login"
        fi
        json_ok "railway" "$USER"
        ;;

    github)
        if ! command -v gh &>/dev/null; then
            fail "GitHub CLI" "Install with:
  brew install gh

Then log in:
  gh auth login"
        fi
        USER=$(gh api user --jq '.login' 2>/dev/null || true)
        if [[ -z "$USER" ]]; then
            fail "GitHub CLI" "Not logged in. Run:
  gh auth login"
        fi
        json_ok "github" "$USER"
        ;;

    auth0)
        if ! command -v auth0 &>/dev/null; then
            fail "Auth0 CLI" "Install with:
  brew install auth0

Then log in:
  auth0 login"
        fi
        TENANT=$(auth0 tenants list --json 2>/dev/null | python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0]['name'] if data else '')" 2>/dev/null || true)
        if [[ -z "$TENANT" ]]; then
            fail "Auth0 CLI" "Not logged in or no tenants found. Run:
  auth0 login"
        fi
        json_ok "auth0" "$TENANT"
        ;;

    dns)
        if [[ -z "${GODADDY_KEY:-}" || -z "${GODADDY_SECRET:-}" ]]; then
            fail "GoDaddy DNS" "GoDaddy API credentials not set. Export these environment variables:
  export GODADDY_KEY=<your-api-key>
  export GODADDY_SECRET=<your-api-secret>

Get credentials at: https://developer.godaddy.com/keys"
        fi
        # Verify the key works by listing domains
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            "https://api.godaddy.com/v1/domains?limit=1" \
            -H "Authorization: sso-key ${GODADDY_KEY}:${GODADDY_SECRET}" 2>/dev/null || echo "000")
        if [[ "$HTTP_STATUS" != "200" ]]; then
            fail "GoDaddy DNS" "GoDaddy API returned HTTP $HTTP_STATUS. Check your credentials.

Get new credentials at: https://developer.godaddy.com/keys"
        fi
        json_ok "dns" "godaddy"
        ;;

    tailscale)
        if ! command -v tailscale &>/dev/null; then
            fail "Tailscale" "Install with:
  brew install tailscale

Then start and authenticate:
  sudo tailscale up"
        fi
        STATUS=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Self',{}).get('HostName',''))" 2>/dev/null || true)
        if [[ -z "$STATUS" ]]; then
            fail "Tailscale" "Not connected. Run:
  sudo tailscale up"
        fi
        json_ok "tailscale" "$STATUS"
        ;;

    pgdump)
        PG_DUMP="/opt/homebrew/opt/libpq/bin/pg_dump"
        if [[ ! -x "$PG_DUMP" ]]; then
            # Try system path
            PG_DUMP=$(command -v pg_dump 2>/dev/null || true)
        fi
        if [[ -z "$PG_DUMP" || ! -x "$PG_DUMP" ]]; then
            fail "pg_dump" "pg_dump not found. Install with:
  brew install libpq

Then use the full path:
  /opt/homebrew/opt/libpq/bin/pg_dump"
        fi
        VERSION=$("$PG_DUMP" --version 2>/dev/null | head -1 || true)
        json_ok "pgdump" "$VERSION"
        ;;

    *)
        echo "Usage: $0 <service>"
        echo ""
        echo "Services: railway, github, auth0, dns, tailscale, pgdump"
        exit 1
        ;;
esac
