#!/usr/bin/env bash
# =============================================================================
# migrate-database.sh — pg_dump/pg_restore wrapper for Replit → Railway
#
# Dumps a source PostgreSQL database and restores it to a destination.
# Uses /opt/homebrew/opt/libpq/bin/ paths for macOS (brew install libpq).
#
# Usage:
#   bash migrate/migrate-database.sh <SOURCE_DATABASE_URL> <DEST_DATABASE_URL>
#
# Or with env vars:
#   SOURCE_DB=postgresql://... DEST_DB=postgresql://... bash migrate/migrate-database.sh
# =============================================================================

set -euo pipefail

SOURCE_DB="${1:-${SOURCE_DB:-}}"
DEST_DB="${2:-${DEST_DB:-}}"

if [[ -z "$SOURCE_DB" || -z "$DEST_DB" ]]; then
    echo "Usage: $0 <SOURCE_DATABASE_URL> <DEST_DATABASE_URL>"
    echo ""
    echo "Or set SOURCE_DB and DEST_DB environment variables."
    exit 1
fi

# Find pg_dump and psql
PG_DUMP="/opt/homebrew/opt/libpq/bin/pg_dump"
PSQL="/opt/homebrew/opt/libpq/bin/psql"

if [[ ! -x "$PG_DUMP" ]]; then
    PG_DUMP=$(command -v pg_dump 2>/dev/null || true)
fi
if [[ ! -x "$PSQL" ]]; then
    PSQL=$(command -v psql 2>/dev/null || true)
fi

if [[ -z "$PG_DUMP" || ! -x "$PG_DUMP" ]]; then
    echo "ERROR: pg_dump not found. Install with: brew install libpq"
    exit 1
fi
if [[ -z "$PSQL" || ! -x "$PSQL" ]]; then
    echo "ERROR: psql not found. Install with: brew install libpq"
    exit 1
fi

DUMP_FILE="migration_dump_$(date +%Y%m%d_%H%M%S).sql"

echo "=== Database Migration ==="
echo ""
echo "pg_dump: $PG_DUMP"
echo "psql:    $PSQL"
echo "Dump file: $DUMP_FILE"
echo ""

# Step 1: Dump source
echo "[1/3] Dumping source database..."
"$PG_DUMP" "$SOURCE_DB" --no-owner --no-acl --clean --if-exists > "$DUMP_FILE"
DUMP_SIZE=$(wc -c < "$DUMP_FILE" | tr -d ' ')
echo "  Dump complete: $DUMP_FILE ($DUMP_SIZE bytes)"

# Step 2: Restore to destination
echo "[2/3] Restoring to destination database..."
"$PSQL" "$DEST_DB" < "$DUMP_FILE" 2>&1 | tail -5
echo "  Restore complete"

# Step 3: Verify
echo "[3/3] Verifying..."
TABLE_COUNT=$("$PSQL" "$DEST_DB" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
echo "  Tables in destination: $TABLE_COUNT"

echo ""
echo "=== Migration complete ==="
echo "Dump file retained at: $DUMP_FILE"
echo "Delete it when you've confirmed the migration: rm $DUMP_FILE"
