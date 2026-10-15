import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  ALLOWED_PAGE_ERRORS,
  CONTAINER_BROWSERS,
  LAUNCH_ARGS,
  expectedShell,
  resolveChromium,
  unexpectedPageErrors,
} from '../browser.mjs';

const TOOL_DIR = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const MODULES_DIR = path.join(TOOL_DIR, 'node_modules');

const shellPath = (base) => path.join(base, 'chromium_headless_shell-1194', 'chrome-linux', 'headless_shell');

test('playwright-core drives headless shell revision 1194, the one fetch-chromium.sh downloads', async () => {
  const shell = expectedShell(MODULES_DIR);
  assert.equal(shell.revision, '1194');
  assert.match(shell.version, /^\d+\.\d+\.\d+\.\d+$/);
  const script = await readFile(path.join(TOOL_DIR, 'fetch-chromium.sh'), 'utf8');
  assert.match(script, new RegExp(`^readonly REVISION=${shell.revision}$`, 'm'));
  assert.match(script, new RegExp(`Chromium ${shell.version.replaceAll('.', '\\.')}`));
});

test('resolves the browser in order: --chromium, FERMAN_CHROMIUM, PLAYWRIGHT_BROWSERS_PATH, /opt/pw-browsers', () => {
  const everything = () => true;
  const env = { FERMAN_CHROMIUM: '/env/shell', PLAYWRIGHT_BROWSERS_PATH: '/pw' };
  const r = (cli, e, exists = everything) => resolveChromium({ cli, env: e, revision: '1194', platform: 'linux', exists });
  assert.deepEqual(r('/cli/shell', env), { executablePath: path.resolve('/cli/shell'), source: '--chromium', tried: [] });
  assert.equal(r(undefined, env).executablePath, path.resolve('/env/shell'));
  assert.equal(r(undefined, env).source, 'FERMAN_CHROMIUM');
  assert.equal(r(undefined, { PLAYWRIGHT_BROWSERS_PATH: '/pw' }).executablePath, shellPath('/pw'));
  assert.equal(r(undefined, { FERMAN_CHROMIUM: '', PLAYWRIGHT_BROWSERS_PATH: '/pw' }).source, 'PLAYWRIGHT_BROWSERS_PATH');

  const onlyContainer = (p) => p === shellPath(CONTAINER_BROWSERS);
  const c = r(undefined, { PLAYWRIGHT_BROWSERS_PATH: '/pw' }, onlyContainer);
  assert.equal(c.executablePath, shellPath(CONTAINER_BROWSERS));
  assert.deepEqual(c.tried, [shellPath('/pw')]);

  const none = r(undefined, {}, () => false);
  assert.equal(none.executablePath, undefined);
  assert.deepEqual(none.tried, [shellPath(CONTAINER_BROWSERS)]);
});

test('an explicit browser path that does not exist is an error', () => {
  const nothing = () => false;
  assert.throws(
    () => resolveChromium({ cli: '/nope', env: {}, revision: '1194', platform: 'linux', exists: nothing }),
    /--chromium: there is no Chromium executable/,
  );
  assert.throws(
    () => resolveChromium({ env: { FERMAN_CHROMIUM: '/nope' }, revision: '1194', platform: 'linux', exists: nothing }),
    /FERMAN_CHROMIUM: there is no Chromium executable/,
  );
});

test('the per-platform executable inside the revision folder', () => {
  const at = (platform) =>
    resolveChromium({ env: {}, revision: '1194', platform, exists: () => true }).executablePath;
  assert.equal(at('darwin'), path.join(CONTAINER_BROWSERS, 'chromium_headless_shell-1194', 'chrome-mac', 'headless_shell'));
  assert.equal(at('win32'), path.join(CONTAINER_BROWSERS, 'chromium_headless_shell-1194', 'chrome-win', 'headless_shell.exe'));
  assert.equal(at('aix'), undefined);
});

test('every launch keeps the dead proxy', () => {
  assert.ok(LAUNCH_ARGS.includes('--proxy-server=http://127.0.0.1:9'));
});

test('page errors fail a board unless an allow-list entry with a reason covers them', () => {
  const errors = ['TypeError: x is undefined', 'ResizeObserver loop limit exceeded'];
  assert.deepEqual(unexpectedPageErrors('a1-1', errors), errors);
  const allowed = [{ boards: ['a1-1'], match: /ResizeObserver loop/, reason: 'benign layout notice' }];
  assert.deepEqual(unexpectedPageErrors('a1-1', errors, allowed), ['TypeError: x is undefined']);
  assert.deepEqual(unexpectedPageErrors('a1-2b', errors, allowed), errors);
  const everywhere = [{ boards: ['*'], match: /ResizeObserver loop/g, reason: 'benign layout notice' }];
  assert.deepEqual(unexpectedPageErrors('a9-9', errors, everywhere), ['TypeError: x is undefined']);
  assert.deepEqual(unexpectedPageErrors('a9-9', errors, everywhere), ['TypeError: x is undefined'], 'g flag is stateless');
  assert.throws(() => unexpectedPageErrors('a1-1', errors, [{ boards: ['*'], match: /x/, reason: ' ' }]), /has no reason/);
});

test('the shipped allow-list gives a reason for every entry', () => {
  for (const entry of ALLOWED_PAGE_ERRORS) {
    assert.ok(entry.reason.trim().length > 0, String(entry.match));
    assert.ok(entry.boards.length > 0, String(entry.match));
  }
});
