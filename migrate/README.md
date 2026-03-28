# Migration: Replit to Railway

This directory contains tools for migrating an existing Replit project to Railway.

## Migration Steps

### 1. Database (PostgreSQL)

Use `migrate-database.sh` to dump your Replit Postgres database and restore it to Railway.

```bash
# Set source and destination DATABASE_URLs
export SOURCE_DB="postgresql://user:pass@host:port/dbname"  # Replit
export DEST_DB="postgresql://user:pass@host:port/railway"    # Railway

bash migrate/migrate-database.sh "$SOURCE_DB" "$DEST_DB"
```

The script uses `/opt/homebrew/opt/libpq/bin/pg_dump` on macOS. Install with `brew install libpq` if needed.

### 2. Blob Storage (Replit Object Storage to Railway Volume)

If your app used Replit Object Storage, you need to transfer files to Railway's filesystem.

**Setup:**
1. Add the storage abstraction: copy `templates/app-stubs/python/storage/filesystem.py` into your app
2. Add temporary migration endpoints to your Railway app (see below)
3. Set `MIGRATION_SECRET` env var on Railway
4. Run the migration script ON REPLIT

```bash
# Run on Replit where Object Storage is available
MIGRATION_SECRET=<secret> RAILWAY_URL=https://your-app.up.railway.app python migrate/migrate-storage.py
```

**Temporary migration endpoints** (add to your Flask app, remove after migration):

```python
@app.route('/api/admin/storage-upload', methods=['POST'])
def admin_storage_upload():
    secret = request.headers.get('X-Migration-Secret')
    if secret != os.environ.get('MIGRATION_SECRET'):
        return 'Unauthorized', 401
    key = urllib.parse.unquote(request.headers.get('X-Storage-Key', ''))
    storage_client.upload_from_bytes(key, request.data)
    return jsonify({'key': key, 'size': len(request.data)})

@app.route('/api/admin/storage-check/<path:key>', methods=['HEAD'])
def admin_storage_check(key):
    secret = request.headers.get('X-Migration-Secret')
    if secret != os.environ.get('MIGRATION_SECRET'):
        return '', 401
    key = urllib.parse.unquote(key)
    return ('', 200) if storage_client.exists(key) else ('', 404)
```

**Important:** Set `MIGRATION_SECRET` BEFORE deploying the endpoint code. Railway env vars only take effect on the next deploy.

### 3. Secrets / Environment Variables

Generate `railway variable set` commands for each secret. Claude will help generate these but will NEVER see the actual values.

```bash
# User runs these manually — Claude generates the command structure
railway variable set 'FLASK_SECRET_KEY=<value>' --skip-deploys
railway variable set 'OPENAI_API_KEY=<value>' --skip-deploys
# ... etc

# After all vars are set, trigger a redeploy:
railway redeploy --service <name> --yes
```

### 4. Auth0 Callback URLs

Update Auth0 app settings to include the new Railway domain:
- Allowed Callback URLs: add `https://new-domain.com/callback`
- Allowed Logout URLs: add `https://new-domain.com/landing`
- Allowed Web Origins: add `https://new-domain.com`

Keep the old Replit URLs until migration is confirmed working.

### 5. Code Changes

- Replace `from replit.object_storage import Client` with `from storage.filesystem import FilesystemStorageClient`
- Add `Dockerfile` and `railway.json` to project root
- Remove Replit-specific files (`.replit`, `replit.nix`) from active use (keep in git history)

### 6. DNS

Point your custom domain to Railway's CNAME target. Railway provides automatic SSL.

```bash
# Check DNS propagation
dig your-app.jimmys.dev +short
```

## Gotchas

- HTTP headers can't carry non-ASCII characters. The migration script URL-encodes storage keys with `urllib.parse.quote(key, safe='')`.
- The migration script is resumable — it checks if each key exists before uploading.
- Replit Object Storage can have thousands of files. Consider migrating only recent/active files.
- The migration script runs ON REPLIT (where `from replit.object_storage import Client` works) and pushes TO Railway via HTTP.
