import assert from 'node:assert/strict';
import { mkdir, mkdtemp, rm, symlink, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, test } from 'node:test';

import { startServer } from '../server.mjs';

let base;
let server;

before(async () => {
  base = await mkdtemp(path.join(os.tmpdir(), 'design-refs-server-'));
  const root = path.join(base, 'root');
  await mkdir(path.join(root, 'sub'), { recursive: true });
  await writeFile(path.join(root, 'a board.dc.html'), '<p>board</p>');
  await writeFile(path.join(root, 'sub', 'style.css'), 'p{}');
  await writeFile(path.join(base, 'secret.txt'), 'outside');
  if (process.platform !== 'win32') await symlink(path.join(base, 'secret.txt'), path.join(root, 'link.txt'));
  server = await startServer(root);
});

after(async () => {
  await server.close();
  await rm(base, { recursive: true, force: true });
});

const get = (p, init) => fetch(`${server.origin}${p}`, init);

test('binds to 127.0.0.1', () => {
  assert.match(server.origin, /^http:\/\/127\.0\.0\.1:\d+$/);
});

test('serves files with encoded names and the right content type', async () => {
  const res = await get('/a%20board.dc.html');
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('content-type'), 'text/html; charset=utf-8');
  assert.equal(await res.text(), '<p>board</p>');
  const css = await get('/sub/style.css');
  assert.equal(css.headers.get('content-type'), 'text/css; charset=utf-8');
});

test('answers HEAD without a body', async () => {
  const res = await get('/sub/style.css', { method: 'HEAD' });
  assert.equal(res.status, 200);
  assert.equal(await res.text(), '');
});

test('refuses writes', async () => {
  for (const method of ['POST', 'PUT', 'DELETE']) {
    const res = await get('/sub/style.css', { method, body: method === 'DELETE' ? undefined : 'x' });
    assert.equal(res.status, 405, method);
    assert.equal(res.headers.get('allow'), 'GET, HEAD');
  }
});

test('never leaves the root', async () => {
  for (const p of ['/../secret.txt', '/%2e%2e/secret.txt', '/sub/..%2f..%2fsecret.txt', '/%2e%2e%5csecret.txt', '/link.txt']) {
    const res = await get(p);
    assert.equal(res.status, 404, p);
  }
});

test('lists no directories and records misses', async () => {
  assert.equal((await get('/sub/')).status, 404);
  assert.equal((await get('/missing.js')).status, 404);
  assert.ok(server.misses.includes('/missing.js'));
});
