#!/usr/bin/env bash
# =============================================================================
# auth0-setup.sh — Non-interactive Auth0 application creation
#
# Creates an Auth0 application with proper callback URLs for the Railway domain.
# Outputs the client credentials as Railway env var commands (user runs them).
#
# Usage:
#   bash infra/auth0-setup.sh --name myapp --domain myapp.jimmys.dev
#   bash infra/auth0-setup.sh --name myapp --domain myapp.up.railway.app --type spa
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# JSON output helpers
# ---------------------------------------------------------------------------
json_step() {
    local step="$1" status="$2" message="$3"
    local extra="${4:-}"
    if [[ -n "$extra" ]]; then
        echo "{\"step\":\"$step\",\"status\":\"$status\",\"message\":\"$message\",$extra}"
    else
        echo "{\"step\":\"$step\",\"status\":\"$status\",\"message\":\"$message\"}"
    fi
}

json_error() {
    local step="$1" message="$2"
    echo "{\"step\":\"$step\",\"status\":\"error\",\"message\":\"$message\"}" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
APP_NAME=""
APP_DOMAIN=""
APP_TYPE="regular"

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)     APP_NAME="$2"; shift 2 ;;
        --domain)   APP_DOMAIN="$2"; shift 2 ;;
        --type)     APP_TYPE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 --name APP_NAME --domain APP_DOMAIN [--type regular|spa]"
            exit 0 ;;
        *) json_error "args" "Unknown argument: $1" ;;
    esac
done

if [[ -z "$APP_NAME" || -z "$APP_DOMAIN" ]]; then
    json_error "args" "Both --name and --domain are required"
fi

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------
if ! command -v auth0 &>/dev/null; then
    json_error "prereq" "Auth0 CLI not installed. Run: brew install auth0 && auth0 login"
fi

# Verify logged in
TENANT=$(auth0 tenants list --json 2>/dev/null | python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0]['name'] if data else '')" 2>/dev/null || true)
if [[ -z "$TENANT" ]]; then
    json_error "prereq" "Not logged in to Auth0. Run: auth0 login"
fi

# ---------------------------------------------------------------------------
# Step 1: Create Auth0 application
# ---------------------------------------------------------------------------
CALLBACK_URL="https://${APP_DOMAIN}/callback"
LOGOUT_URL="https://${APP_DOMAIN}/landing"
WEB_ORIGIN="https://${APP_DOMAIN}"

AUTH0_OUTPUT=$(auth0 apps create \
    --name "$APP_NAME" \
    --type "$APP_TYPE" \
    --callbacks "$CALLBACK_URL" \
    --logout-urls "$LOGOUT_URL" \
    --origins "$WEB_ORIGIN" \
    --reveal-secrets \
    --json 2>/dev/null || echo "")

if [[ -z "$AUTH0_OUTPUT" ]]; then
    json_error "create_app" "Auth0 app creation failed. Create manually at https://manage.auth0.com"
fi

AUTH0_CLIENT_ID=$(echo "$AUTH0_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('client_id',''))" 2>/dev/null)
AUTH0_CLIENT_SECRET=$(echo "$AUTH0_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('client_secret',''))" 2>/dev/null)
AUTH0_DOMAIN_VAL=$(echo "$AUTH0_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('domain',''))" 2>/dev/null)

if [[ -z "$AUTH0_CLIENT_ID" ]]; then
    json_error "create_app" "Could not parse Auth0 response"
fi

json_step "create_app" "ok" "Auth0 app created: $APP_NAME" "\"client_id\":\"$AUTH0_CLIENT_ID\",\"domain\":\"$AUTH0_DOMAIN_VAL\""

# ---------------------------------------------------------------------------
# Step 2: Output Railway env var commands
# ---------------------------------------------------------------------------
# Claude should instruct the user to run these — Claude never sees the secret values directly
echo ""
echo "{"
echo "  \"summary\": {"
echo "    \"app_name\": \"$APP_NAME\","
echo "    \"client_id\": \"$AUTH0_CLIENT_ID\","
echo "    \"auth0_domain\": \"$AUTH0_DOMAIN_VAL\","
echo "    \"callback_url\": \"$CALLBACK_URL\","
echo "    \"logout_url\": \"$LOGOUT_URL\","
echo "    \"railway_env_commands\": ["
echo "      \"railway variable set 'AUTH0_CLIENT_ID=$AUTH0_CLIENT_ID' --skip-deploys\","
echo "      \"railway variable set 'AUTH0_CLIENT_SECRET=$AUTH0_CLIENT_SECRET' --skip-deploys\","
echo "      \"railway variable set 'AUTH0_DOMAIN=$AUTH0_DOMAIN_VAL' --skip-deploys\""
echo "    ]"
echo "  }"
echo "}"
