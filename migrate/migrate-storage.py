#!/usr/bin/env python3
"""
One-time migration script: Replit Object Storage -> Railway filesystem storage.

Run this ON REPLIT where Object Storage is available.
It downloads every blob and POSTs it to Railway's /api/admin/storage-upload endpoint.

Usage:
    MIGRATION_SECRET=<secret> RAILWAY_URL=https://your-app.up.railway.app python migrate/migrate-storage.py

Set the same MIGRATION_SECRET as an env var on Railway BEFORE deploying the
migration endpoints (env vars only take effect on the next deploy).

Prerequisites on Railway app:
    POST /api/admin/storage-upload  — receives blob, stores it
    HEAD /api/admin/storage-check/<key>  — checks if key exists (for resume)
    Both protected by X-Migration-Secret header.

See migrate/README.md for endpoint implementation examples.
"""

import os
import sys
import requests
from urllib.parse import quote

RAILWAY_URL = os.environ.get("RAILWAY_URL", "").rstrip("/")
MIGRATION_SECRET = os.environ.get("MIGRATION_SECRET")

if not RAILWAY_URL:
    print("ERROR: Set RAILWAY_URL env var (e.g. https://your-app.up.railway.app)")
    sys.exit(1)

if not MIGRATION_SECRET:
    print("ERROR: Set MIGRATION_SECRET env var (must match Railway's)")
    sys.exit(1)

UPLOAD_URL = f"{RAILWAY_URL}/api/admin/storage-upload"

# Import Replit Object Storage — this only works on Replit
try:
    from replit.object_storage import Client
except ImportError:
    print("ERROR: replit.object_storage not available.")
    print("This script must be run ON REPLIT where the SDK is installed.")
    sys.exit(1)

client = Client()
objects = client.list()
print(f"Found {len(objects)} objects in Replit Object Storage")

failed = []
skipped = []
uploaded = []

for i, obj in enumerate(objects):
    key = obj.name
    print(f"[{i+1}/{len(objects)}] {key}...", end=" ", flush=True)

    # Check if already exists on Railway (resume support)
    try:
        check = requests.head(
            f"{RAILWAY_URL}/api/admin/storage-check/{quote(key, safe='')}",
            headers={"X-Migration-Secret": MIGRATION_SECRET},
            timeout=10,
        )
        if check.status_code == 200:
            print("SKIP (exists)")
            skipped.append(key)
            continue
    except Exception as e:
        print(f"WARN check failed: {e}, uploading anyway...", end=" ")

    # Download from Replit
    try:
        data = client.download_as_bytes(key)
    except Exception as e:
        print(f"FAIL download: {e}")
        failed.append((key, str(e)))
        continue

    # Upload to Railway
    # URL-encode the key in the header to handle non-ASCII characters
    try:
        resp = requests.post(
            UPLOAD_URL,
            data=data,
            headers={
                "X-Migration-Secret": MIGRATION_SECRET,
                "X-Storage-Key": quote(key, safe=""),
                "Content-Type": "application/octet-stream",
            },
            timeout=120,
        )
        if resp.status_code == 200:
            print(f"OK ({len(data)} bytes)")
            uploaded.append(key)
        else:
            print(f"FAIL upload: {resp.status_code} {resp.text[:100]}")
            failed.append((key, resp.text[:100]))
    except Exception as e:
        print(f"FAIL upload: {e}")
        failed.append((key, str(e)))

print(f"\n=== MIGRATION COMPLETE ===")
print(f"Uploaded: {len(uploaded)}")
print(f"Skipped:  {len(skipped)}")
print(f"Failed:   {len(failed)}")
if failed:
    print("\nFailed files:")
    for key, err in failed:
        print(f"  {key}: {err}")
