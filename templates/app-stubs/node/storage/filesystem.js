/**
 * Filesystem-based storage backend for Railway Volume (or local dev).
 *
 * Drop-in replacement for Replit Object Storage with the same API:
 *   - uploadFromBytes(key, buffer)
 *   - downloadAsBytes(key) -> Buffer
 *   - exists(key) -> boolean
 *   - delete(key)
 *   - list() -> array of { name }
 *
 * All files are stored flat in a single directory (STORAGE_ROOT).
 * Default: /data/storage (Railway Volume mount) or ./local_storage (dev).
 * Override with STORAGE_ROOT environment variable.
 */

const fs = require('fs');
const path = require('path');

function getStorageRoot() {
  if (process.env.STORAGE_ROOT) {
    return process.env.STORAGE_ROOT;
  }
  // Railway Volume default mount point
  if (fs.existsSync('/data')) {
    return '/data/storage';
  }
  // Local development fallback
  return path.join(process.cwd(), 'local_storage');
}

class FilesystemStorageClient {
  constructor(root) {
    this._root = root || getStorageRoot();
    fs.mkdirSync(this._root, { recursive: true });
    console.log(`Filesystem storage initialized at: ${this._root}`);
  }

  _path(key) {
    // Sanitize key to prevent path traversal
    const safeKey = path.basename(key);
    return path.join(this._root, safeKey);
  }

  uploadFromBytes(key, buffer) {
    fs.writeFileSync(this._path(key), buffer);
  }

  downloadAsBytes(key) {
    const filePath = this._path(key);
    if (!fs.existsSync(filePath)) {
      throw new Error(`Storage key not found: ${key}`);
    }
    return fs.readFileSync(filePath);
  }

  exists(key) {
    return fs.existsSync(this._path(key));
  }

  delete(key) {
    const filePath = this._path(key);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
  }

  list() {
    if (!fs.existsSync(this._root)) {
      return [];
    }
    return fs.readdirSync(this._root)
      .filter(f => fs.statSync(path.join(this._root, f)).isFile())
      .sort()
      .map(name => ({ name }));
  }
}

module.exports = { FilesystemStorageClient };
