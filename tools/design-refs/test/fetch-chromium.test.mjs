// Runs fetch-chromium.sh on a small stand-in zip (--zip), so no download is needed.

import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { accessSync, constants } from 'node:fs';
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, test } from 'node:test';
import { fileURLToPath } from 'node:url';

const TOOL_DIR = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SCRIPT = path.join(TOOL_DIR, 'fetch-chromium.sh');

const has = (tool) => spawnSync('sh', ['-c', `command -v ${tool}`]).status === 0;
const skip =
  process.platform !== 'linux' || os.arch() !== 'x64' || !['bash', 'zip', 'unzip'].every(has)
    ? 'needs Linux x64 with bash, zip and unzip'
    : false;

let base;
let zip;
let zipHash;

before(async () => {
  if (skip) return;
  base = await mkdtemp(path.join(os.tmpdir(), 'design-refs-fetch-'));
  const src = path.join(base, 'src');
  await mkdir(path.join(src, 'chrome-linux'), { recursive: true });
  await writeFile(path.join(src, 'chrome-linux', 'headless_shell'), '#!/bin/sh\necho stand-in\n');
  await chmod(path.join(src, 'chrome-linux', 'headless_shell'), 0o755);
  zip = path.join(base, 'shell.zip');
  assert.equal(spawnSync('zip', ['-qr', zip, 'chrome-linux'], { cwd: src }).status, 0);
  zipHash = createHash('sha256').update(await readFile(zip)).digest('hex');
});

after(async () => {
  if (base) await rm(base, { recursive: true, force: true });
});

/** Runs [script] with a clean CI environment, so its warnings never become CI annotations. */
function run(script, args, extraEnv = {}) {
  const env = { ...process.env, ...extraEnv };
  if (!('GITHUB_ACTIONS' in extraEnv)) delete env.GITHUB_ACTIONS;
  if (!('GITHUB_STEP_SUMMARY' in extraEnv)) delete env.GITHUB_STEP_SUMMARY;
  return spawnSync('bash', [script, ...args], { encoding: 'utf8', env });
}

/** A copy of the script with CHROMIUM_SHA256 pinned to [hash]. */
async function pinnedScript(hash) {
  const text = await readFile(SCRIPT, 'utf8');
  assert.match(text, /^readonly CHROMIUM_SHA256=UNPINNED$/m);
  const file = path.join(base, `pinned-${hash.slice(0, 8)}.sh`);
  await writeFile(file, text.replace(/^readonly CHROMIUM_SHA256=UNPINNED$/m, `readonly CHROMIUM_SHA256=${hash}`));
  return file;
}

test('unpinned: unpacks, prints the executable, and warns loudly with the computed hash', { skip }, async () => {
  const cache = path.join(base, 'cache-unpinned');
  const summary = path.join(base, 'summary.md');
  const r = run(SCRIPT, ['--zip', zip, cache], { GITHUB_STEP_SUMMARY: summary });
  assert.equal(r.status, 0, r.stderr);
  const exe = path.join(cache, 'chromium_headless_shell-1194', 'chrome-linux', 'headless_shell');
  assert.equal(r.stdout, `${exe}\n`);
  accessSync(exe, constants.X_OK);
  assert.match(r.stderr, /WARNING: CHROMIUM_SHA256 is not pinned/);
  assert.ok(r.stderr.includes(zipHash), 'the computed hash is printed');
  assert.ok((await readFile(summary, 'utf8')).includes(zipHash), 'and written to the step summary');
  assert.equal((await readFile(path.join(cache, 'chromium_headless_shell-1194', 'ZIP_SHA256'), 'utf8')).trim(), zipHash);

  // A second run uses the cache and downloads nothing (no --zip, and the cache is complete).
  const again = run(SCRIPT, [cache]);
  assert.equal(again.status, 0, again.stderr);
  assert.equal(again.stdout, `${exe}\n`);
  assert.doesNotMatch(again.stderr, /downloading/);
});

test('unpinned on GitHub Actions: also a ::warning:: annotation, on stderr only', { skip }, () => {
  const r = run(SCRIPT, ['--zip', zip, path.join(base, 'cache-gha')], { GITHUB_ACTIONS: 'true' });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stderr, /^::warning title=Chromium download not pinned::/m);
  assert.doesNotMatch(r.stdout, /warning/i);
});

test('pinned: accepts the zip with that hash', { skip }, async () => {
  const cache = path.join(base, 'cache-pinned');
  const r = run(await pinnedScript(zipHash), ['--zip', zip, cache]);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stderr, /SHA-256 ok/);
  assert.doesNotMatch(r.stderr, /WARNING/);
  const again = run(await pinnedScript(zipHash), [cache]);
  assert.equal(again.status, 0, again.stderr);
  assert.match(again.stderr, /cached:/);
});

test('pinned: refuses a zip with another hash and unpacks nothing', { skip }, async () => {
  const cache = path.join(base, 'cache-mismatch');
  const r = run(await pinnedScript('0'.repeat(64)), ['--zip', zip, cache]);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /SHA-256 mismatch/);
  assert.equal(r.stdout, '');
  assert.throws(() => accessSync(path.join(cache, 'chromium_headless_shell-1194')));
});

test('refuses a zip without the headless shell', { skip }, async () => {
  const other = path.join(base, 'other');
  await mkdir(other, { recursive: true });
  await writeFile(path.join(other, 'readme.txt'), 'x');
  const bad = path.join(base, 'bad.zip');
  assert.equal(spawnSync('zip', ['-q', bad, 'readme.txt'], { cwd: other }).status, 0);
  const r = run(SCRIPT, ['--zip', bad, path.join(base, 'cache-bad')]);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /holds no chrome-linux\/headless_shell/);
});
