import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { FONT_FILE_PREFIX, createOfflineRouter } from '../routes.mjs';

const TOOL_DIR = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const DESIGN_DIR = path.join(TOOL_DIR, '..', '..', 'design');
const MODULES_DIR = path.join(TOOL_DIR, 'node_modules');
const ORIGIN = 'http://127.0.0.1:5555';

/**
 * Installs the router on a fake browser context and returns `run(url, method)`, which passes one
 * request through the route handler and says what the handler did with it.
 */
async function setup() {
  const router = await createOfflineRouter({ designDir: DESIGN_DIR, modulesDir: MODULES_DIR, origin: ORIGIN });
  const contextViolations = [];
  let pattern;
  let handler;
  await router.install(
    {
      route: async (p, h) => {
        pattern = p;
        handler = h;
      },
    },
    (v) => contextViolations.push(v),
  );
  const run = async (url, method = 'GET') => {
    let outcome;
    await handler({
      request: () => ({ url: () => url, method: () => method }),
      continue: async () => {
        outcome = { action: 'continue' };
      },
      fulfill: async (response) => {
        outcome = { action: 'fulfill', ...response };
      },
      abort: async (code) => {
        outcome = { action: 'abort', code };
      },
    });
    return outcome;
  };
  return { router, run, contextViolations, pattern: () => pattern };
}

test('routes every request of the context', async () => {
  const { pattern } = await setup();
  assert.equal(pattern(), '**/*');
});

test('lets the local design server through', async () => {
  const { router, run } = await setup();
  assert.equal((await run(`${ORIGIN}/01%20First%20run%20and%20files.dc.html`)).action, 'continue');
  assert.equal(router.violations.length, 0);
});

test('serves the pinned unpkg script from node_modules', async () => {
  const { router, run } = await setup();
  const r = await run('https://unpkg.com/react@18.3.1/umd/react.production.min.js');
  assert.equal(r.action, 'fulfill');
  assert.equal(r.status, 200);
  assert.equal(r.headers['content-type'], 'text/javascript; charset=utf-8');
  assert.equal(r.headers['access-control-allow-origin'], '*');
  assert.deepEqual(r.body, await readFile(path.join(MODULES_DIR, 'react', 'umd', 'react.production.min.js')));
  assert.equal(router.served.scripts, 1);
  assert.equal(router.violations.length, 0);
});

test('serves the fonts.googleapis.com stylesheet and its font files locally', async () => {
  const { router, run } = await setup();
  const css = await run('https://fonts.googleapis.com/css2?family=Caveat:wght@500&display=swap');
  assert.equal(css.action, 'fulfill');
  assert.equal(css.status, 200);
  assert.equal(css.headers['content-type'], 'text/css; charset=utf-8');
  assert.match(css.body, /font-family: 'Caveat';/);
  const urls = [...css.body.matchAll(/url\(([^)]+)\)/g)].map((m) => m[1]);
  assert.ok(urls.length > 0);
  for (const url of urls) assert.ok(url.startsWith(`${FONT_FILE_PREFIX}caveat/`), url);

  const font = await run(urls[0]);
  assert.equal(font.action, 'fulfill');
  assert.equal(font.status, 200);
  assert.equal(font.headers['content-type'], 'font/woff2');
  const file = urls[0].slice(`${FONT_FILE_PREFIX}caveat/`.length);
  assert.deepEqual(font.body, await readFile(path.join(MODULES_DIR, '@fontsource', 'caveat', 'files', file)));
  assert.deepEqual(router.served, { scripts: 0, stylesheets: 1, fontFiles: 1 });
  assert.equal(router.violations.length, 0);
});

test('aborts and records every other request', async () => {
  const { router, run, contextViolations } = await setup();
  const blocked = [
    ['https://example.com/', 'GET'],
    ['http://127.0.0.1:5556/x', 'GET'],
    ['http://localhost:5555/x', 'GET'],
    ['https://unpkg.com/react@18.3.1/umd/react.development.js', 'GET'],
    ['https://unpkg.com/react@18.3.1/umd/react.production.min.js', 'POST'],
    ['https://fonts.googleapis.com/css2?family=Roboto', 'GET'],
    ['https://fonts.googleapis.com/css?family=Caveat', 'GET'],
    ['https://fonts.gstatic.com/s/caveat/v18/x.woff2', 'GET'],
    ['https://fonts.gstatic.com/fontsource/caveat/../../x/y.woff2', 'GET'],
    ['https://fonts.gstatic.com/fontsource/roboto/roboto-latin-400-normal.woff2', 'GET'],
    ['wss://example.com/socket', 'GET'],
  ];
  for (const [url, method] of blocked) {
    const r = await run(url, method);
    assert.equal(r.action, 'abort', `${method} ${url}`);
    assert.equal(r.code, 'blockedbyclient');
  }
  assert.equal(router.violations.length, blocked.length);
  assert.deepEqual(contextViolations, router.violations);
  for (const v of router.violations) assert.ok(v.reason.length > 0, v.url);
  assert.deepEqual(router.served, { scripts: 0, stylesheets: 0, fontFiles: 0 });
});
