"""
Filesystem-based storage backend for Railway Volume (or local dev).

Drop-in replacement for Replit Object Storage with the same API:
  - upload_from_bytes(key, data)
  - download_as_bytes(key) -> bytes
  - exists(key) -> bool
  - delete(key)
  - list() -> list of objects with .name attribute

All files are stored flat in a single directory (STORAGE_ROOT).
Default: /data/storage (Railway Volume mount) or ./local_storage (dev).
Override with STORAGE_ROOT environment variable.
"""

import os
import logging
from pathlib import Path


def _get_storage_root():
    """Determine storage root directory."""
    root = os.environ.get("STORAGE_ROOT")
    if root:
        return Path(root)
    # Railway Volume default mount point
    if os.path.isdir("/data"):
        return Path("/data/storage")
    # Local development fallback
    return Path("local_storage")


class StorageObject:
    """Minimal object returned by list() — matches Replit's .name interface."""

    def __init__(self, name):
        self.name = name

    def __repr__(self):
        return f"StorageObject({self.name!r})"


class FilesystemStorageClient:
    """Filesystem-backed storage client compatible with Replit Object Storage API."""

    def __init__(self, root=None):
        self._root = Path(root) if root else _get_storage_root()
        self._root.mkdir(parents=True, exist_ok=True)
        logging.info(f"Filesystem storage initialized at: {self._root}")

    def _path(self, key):
        # Sanitize key to prevent path traversal
        safe_key = Path(key).name
        return self._root / safe_key

    def upload_from_bytes(self, key, data):
        """Write bytes to a file."""
        path = self._path(key)
        path.write_bytes(data)

    def download_as_bytes(self, key):
        """Read a file and return its bytes."""
        path = self._path(key)
        if not path.exists():
            raise FileNotFoundError(f"Storage key not found: {key}")
        return path.read_bytes()

    def exists(self, key):
        """Check if a key exists in storage."""
        return self._path(key).exists()

    def delete(self, key):
        """Delete a file from storage."""
        path = self._path(key)
        if path.exists():
            path.unlink()

    def list(self):
        """List all objects in storage. Returns objects with a .name attribute."""
        if not self._root.exists():
            return []
        return [StorageObject(f.name) for f in sorted(self._root.iterdir()) if f.is_file()]
