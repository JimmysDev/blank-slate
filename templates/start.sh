#!/bin/bash
# =============================================================================
# start.sh — Container entrypoint
#
# Optional wrapper for app startup. Useful for:
# - Tailscale integration (uncomment below)
# - Pre-flight checks
# - Multiple process management
#
# If you don't need any of this, you can remove start.sh and set CMD directly
# in your Dockerfile.
# =============================================================================

# --- Tailscale (optional — uncomment to enable SSH access) ---
# Requires TAILSCALE_AUTHKEY env var set in Railway
# if [ -n "$TAILSCALE_AUTHKEY" ]; then
#     tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &
#     tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="${RAILWAY_SERVICE_NAME:-app}"
# fi

# Start the application
exec "$@"
