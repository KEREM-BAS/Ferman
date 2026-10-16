// A static, read-only HTTP server for the design export, bound to 127.0.0.1.
//
// It answers GET and HEAD for regular files under one root directory and nothing else: no
// directory listings, no writes, no paths outside the root (also not through symlinks).

import { createServer } from 'node:http';
import { readFile, realpath, stat } from 'node:fs/promises';
import path from 'node:path';

const CONTENT_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
};

/**
 * Maps a request URL to a regular file inside [root], or returns null when there is none or the
 * path would leave the root. [root] must already be a real path.
 *
 * @param {string} root
 * @param {string} requestUrl
 * @returns {Promise<string | null>}
 */
export async function resolveFile(root, requestUrl) {
  let relative;
  try {
    relative = decodeURIComponent(new URL(requestUrl, 'http://127.0.0.1').pathname);
  } catch {
    return null;
  }
  if (relative.includes('\0')) return null;
  const inside = (p) => p.startsWith(root + path.sep);
  const candidate = path.join(root, relative);
  if (!inside(candidate)) return null;
  try {
    const real = await realpath(candidate);
    if (!inside(real)) return null;
    return (await stat(real)).isFile() ? real : null;
  } catch {
    return null;
  }
}

/**
 * Starts the server on an ephemeral port of 127.0.0.1.
 *
 * Returns the origin to load pages from, the list of request paths that found no file (for the
 * caller to report), and `close()`.
 *
 * @param {string} root directory to serve
 * @returns {Promise<{origin: string, misses: string[], close: () => Promise<void>}>}
 */
export async function startServer(root) {
  const realRoot = await realpath(root);
  const misses = [];
  const server = createServer(async (req, res) => {
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.writeHead(405, { Allow: 'GET, HEAD' }).end();
      return;
    }
    const file = await resolveFile(realRoot, req.url ?? '/');
    if (file === null) {
      misses.push(req.url ?? '/');
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }).end('Not found\n');
      return;
    }
    try {
      const body = await readFile(file);
      res.writeHead(200, {
        'Content-Type': CONTENT_TYPES[path.extname(file).toLowerCase()] ?? 'application/octet-stream',
        'Content-Length': body.length,
        'Cache-Control': 'no-store',
        'X-Content-Type-Options': 'nosniff',
      });
      res.end(req.method === 'HEAD' ? undefined : body);
    } catch {
      res.writeHead(500).end();
    }
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const { port } = /** @type {import('node:net').AddressInfo} */ (server.address());
  return {
    origin: `http://127.0.0.1:${port}`,
    misses,
    close: () =>
      new Promise((resolve) => {
        server.closeAllConnections();
        server.close(() => resolve());
      }),
  };
}
