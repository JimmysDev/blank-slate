#!/usr/bin/env bash
# =============================================================================
# railway-setup.sh — Non-interactive Railway project provisioning
#
# Creates a Railway project with optional PostgreSQL, volume, custom domain,
# and GoDaddy DNS records. All configuration via flags — no interactive prompts.
# Outputs JSON for every step so Claude can parse results.
#
# Usage:
#   bash infra/railway-setup.sh --name myapp --postgres --volume /data
#   bash infra/railway-setup.sh --name myapp --domain app.jimmys.dev --env-file .env.railway
#   bash infra/railway-setup.sh --config setup.json
#
# Flags:
#   --name NAME             Project name (required)
#   --config FILE           Load all options from JSON config file
#   --postgres              Add PostgreSQL database
#   --volume MOUNT          Add persistent volume at MOUNT path (e.g. /data)
#   --domain DOMAIN         Custom domain (e.g. app.jimmys.dev)
#   --godaddy-domain ROOT   Root domain for GoDaddy DNS (e.g. jimmys.dev)
#   --env KEY=VALUE         Set environment variable (repeatable)
#   --env-file FILE         Load env vars from file
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
CONFIG_FILE=""
PROJECT_NAME=""
WANT_POSTGRES=false
VOLUME_MOUNT=""
CUSTOM_DOMAIN=""
GODADDY_DOMAIN=""
ENV_FILE=""
declare -A EXTRA_ENV=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --config)           CONFIG_FILE="$2"; shift 2 ;;
        --name)             PROJECT_NAME="$2"; shift 2 ;;
        --postgres)         WANT_POSTGRES=true; shift ;;
        --volume)           VOLUME_MOUNT="$2"; shift 2 ;;
        --domain)           CUSTOM_DOMAIN="$2"; shift 2 ;;
        --godaddy-domain)   GODADDY_DOMAIN="$2"; shift 2 ;;
        --env-file)         ENV_FILE="$2"; shift 2 ;;
        --env)              IFS='=' read -r k v <<< "$2"; EXTRA_ENV[$k]="$v"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 --name NAME [--postgres] [--volume /mount] [--domain sub.domain.com]"
            echo "       [--godaddy-domain domain.com] [--env-file .env] [--env KEY=VALUE]"
            echo "       [--config setup.json]"
            exit 0 ;;
        *) json_error "args" "Unknown argument: $1" ;;
    esac
done

# ---------------------------------------------------------------------------
# Load config file if provided
# ---------------------------------------------------------------------------
if [[ -n "$CONFIG_FILE" ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
        json_error "config" "Config file not found: $CONFIG_FILE"
    fi
    eval "$(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    c = json.load(f)
print(f'PROJECT_NAME=\"{c.get(\"name\", \"\")}\"')
print(f'WANT_POSTGRES={\"true\" if c.get(\"postgres\") else \"false\"}')
print(f'VOLUME_MOUNT=\"{c.get(\"volume\", \"\")}\"')
print(f'CUSTOM_DOMAIN=\"{c.get(\"domain\", \"\")}\"')
print(f'GODADDY_DOMAIN=\"{c.get(\"godaddy_domain\", \"\")}\"')
print(f'ENV_FILE=\"{c.get(\"env_file\", \"\")}\"')
for k, v in c.get('env', {}).items():
    print(f'EXTRA_ENV[{k}]=\"{v}\"')
")"
fi

# Validate required args
if [[ -z "$PROJECT_NAME" ]]; then
    json_error "args" "Project name is required. Use --name NAME"
fi

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------
if ! command -v railway &>/dev/null; then
    json_error "prereq" "Railway CLI not installed. Run: brew install railway && railway login"
fi
if ! railway whoami &>/dev/null; then
    json_error "prereq" "Not logged in to Railway. Run: railway login"
fi

# ---------------------------------------------------------------------------
# Step 1: Create Railway project
# ---------------------------------------------------------------------------
# Check if project already exists (idempotent)
EXISTING=$(railway status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('name',''))" 2>/dev/null || true)
if [[ "$EXISTING" == "$PROJECT_NAME" ]]; then
    json_step "create_project" "skipped" "Project already exists: $PROJECT_NAME"
else
    railway init --name "$PROJECT_NAME" 2>/dev/null
    json_step "create_project" "ok" "Created project: $PROJECT_NAME"
fi

# Get project ID for dashboard URLs
PROJECT_ID=$(railway status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)

# ---------------------------------------------------------------------------
# Step 2: Add PostgreSQL
# ---------------------------------------------------------------------------
if [[ "$WANT_POSTGRES" == true ]]; then
    railway add --database postgres 2>/dev/null && \
        json_step "add_postgres" "ok" "PostgreSQL added — DATABASE_URL will be auto-injected" || \
        json_step "add_postgres" "warn" "PostgreSQL may already exist or could not be added via CLI"
fi

# ---------------------------------------------------------------------------
# Step 3: Add volume
# ---------------------------------------------------------------------------
if [[ -n "$VOLUME_MOUNT" ]]; then
    railway volume add --mount "$VOLUME_MOUNT" 2>/dev/null && \
        json_step "add_volume" "ok" "Volume mounted at $VOLUME_MOUNT" || \
        json_step "add_volume" "warn" "Volume may need to be added in Railway dashboard at mount: $VOLUME_MOUNT"
fi

# ---------------------------------------------------------------------------
# Step 4: Set environment variables
# ---------------------------------------------------------------------------
ENV_COUNT=0

# From env file
if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        # Strip quotes
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        # Use single-quoted to avoid trailing newline gotcha
        railway variable set "'${key}=${value}'" --skip-deploys 2>/dev/null && \
            ((ENV_COUNT++)) || true
    done < "$ENV_FILE"
fi

# From --env flags
for key in "${!EXTRA_ENV[@]}"; do
    railway variable set "'${key}=${EXTRA_ENV[$key]}'" --skip-deploys 2>/dev/null && \
        ((ENV_COUNT++)) || true
done

if [[ $ENV_COUNT -gt 0 ]]; then
    json_step "set_env_vars" "ok" "Set $ENV_COUNT environment variable(s)"
fi

# ---------------------------------------------------------------------------
# Step 5: Add domain
# ---------------------------------------------------------------------------
RAILWAY_DOMAIN=""
RAILWAY_TARGET=""

if [[ -n "$CUSTOM_DOMAIN" ]]; then
    DOMAIN_OUTPUT=$(railway domain "$CUSTOM_DOMAIN" --json 2>/dev/null || echo "")
    if [[ -n "$DOMAIN_OUTPUT" ]]; then
        RAILWAY_TARGET=$(echo "$DOMAIN_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('dnsRecords',[{}])[0].get('value','') if d.get('dnsRecords') else d.get('domain',''))" 2>/dev/null || true)
        RAILWAY_DOMAIN="$CUSTOM_DOMAIN"
        json_step "add_domain" "ok" "Custom domain added: $CUSTOM_DOMAIN" "\"cname_target\":\"$RAILWAY_TARGET\""
    else
        json_step "add_domain" "warn" "Could not add custom domain via CLI — add in Railway dashboard"
    fi
else
    DOMAIN_OUTPUT=$(railway domain --json 2>/dev/null || echo "")
    if [[ -n "$DOMAIN_OUTPUT" ]]; then
        RAILWAY_DOMAIN=$(echo "$DOMAIN_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('domain',''))" 2>/dev/null || true)
        json_step "add_domain" "ok" "Railway domain generated: $RAILWAY_DOMAIN"
    else
        json_step "add_domain" "warn" "Could not generate domain — generate in Railway dashboard"
    fi
fi

# ---------------------------------------------------------------------------
# Step 6: GoDaddy DNS (if custom domain + creds available)
# ---------------------------------------------------------------------------
if [[ -n "$CUSTOM_DOMAIN" && -n "$GODADDY_DOMAIN" && -n "${GODADDY_KEY:-}" && -n "${GODADDY_SECRET:-}" && -n "$RAILWAY_TARGET" ]]; then
    SUBDOMAIN="${CUSTOM_DOMAIN%.$GODADDY_DOMAIN}"
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -X PUT "https://api.godaddy.com/v1/domains/${GODADDY_DOMAIN}/records/CNAME/${SUBDOMAIN}" \
        -H "Authorization: sso-key ${GODADDY_KEY}:${GODADDY_SECRET}" \
        -H "Content-Type: application/json" \
        -d "[{\"data\": \"${RAILWAY_TARGET}\", \"ttl\": 600}]")

    if [[ "$HTTP_STATUS" == "200" ]]; then
        json_step "godaddy_dns" "ok" "CNAME record created: $SUBDOMAIN.$GODADDY_DOMAIN → $RAILWAY_TARGET"
    else
        json_step "godaddy_dns" "warn" "GoDaddy API returned HTTP $HTTP_STATUS — create CNAME manually: $SUBDOMAIN → $RAILWAY_TARGET"
    fi
elif [[ -n "$CUSTOM_DOMAIN" && -z "${GODADDY_KEY:-}" ]]; then
    json_step "godaddy_dns" "skipped" "GoDaddy credentials not set — create DNS records manually"
fi

# ---------------------------------------------------------------------------
# Step 7: Get service ID for dashboard URL
# ---------------------------------------------------------------------------
SERVICE_ID=$(railway status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('serviceId','') or d.get('service',{}).get('id',''))" 2>/dev/null || true)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "{"
echo "  \"summary\": {"
echo "    \"project\": \"$PROJECT_NAME\","
echo "    \"project_id\": \"$PROJECT_ID\","
echo "    \"domain\": \"${RAILWAY_DOMAIN:-none}\","
echo "    \"postgres\": $WANT_POSTGRES,"
echo "    \"volume\": \"${VOLUME_MOUNT:-none}\","
echo "    \"env_vars_set\": $ENV_COUNT,"
echo "    \"dashboard\": \"https://railway.com/project/$PROJECT_ID\","
echo "    \"github_link_url\": \"https://railway.com/project/$PROJECT_ID/service/$SERVICE_ID/settings\","
echo "    \"manual_step\": \"Connect GitHub repo in Railway dashboard → Settings → Source\""
echo "  }"
echo "}"
