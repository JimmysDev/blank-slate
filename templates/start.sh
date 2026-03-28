#!/bin/bash
# =============================================================================
# start.sh — Container entrypoint
#
# Optional wrapper for app startup. Useful for:
# - Tailscale SSH into the container (uncomment below)
# - Pre-flight checks
# - Multiple process management
#
# If you don't need any of this, you can remove start.sh and set CMD directly
# in your Dockerfile.
#
# NOTE: For local dev access from your phone/other devices, just run Tailscale
# on your Mac — your dev server is accessible at http://jimmys-mac-mini:<port>.
# The section below is only for SSH access into the PRODUCTION Railway container.
# =============================================================================

# --- Tailscale SSH into container (optional — uncomment to enable) ---
# Requires: TAILSCALE_AUTHKEY env var set in Railway
# Requires: Tailscale installed in Dockerfile (RUN curl -fsSL https://tailscale.com/install.sh | sh)
# Requires: State dir on Railway Volume (RUN mkdir -p /data/tailscale)
# if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
#     tailscaled --tun=userspace-networking --state=/data/tailscale/ &
#     sleep 2
#     tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="${RAILWAY_SERVICE_NAME:-app}" --ssh
#     echo "Tailscale SSH enabled: $(tailscale ip -4)"
# fi

# Start the application
exec "$@"
