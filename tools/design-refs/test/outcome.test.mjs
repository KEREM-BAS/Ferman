import assert from 'node:assert/strict';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { loadBoards } from '../boards.mjs';
import { selectTargets } from '../cli.mjs';
import { countCheck, runStatus } from '../outcome.mjs';
import { createOfflineRouter } from '../routes.mjs';

const TOOL_DIR = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const DESIGN_DIR = path.join(TOOL_DIR, '..', '..', 'design');
const MODULES_DIR = path.join(TOOL_DIR, 'node_modules');
const ORIGIN = 'http://127.0.0.1:5555';

/** A run in which nothing went wrong; each test spoils one part of it. */
const clean = () => ({ failures: [], missing: [], violations: [], misses: [], mismatches: [] });

/** The boards of the @m1 set, as `--only @m1` requests them. */
async function m1Targets() {
  return selectTargets(await loadBoards(path.join(TOOL_DIR, 'boards.json')), ['@m1']);
}

test('a run with a PNG for every requested board and nothing else wrong passes', async () => {
  const targets = await m1Targets();
  const rendered = new Map(targets.map((t) => [t.id, { id: t.id }]));
  const { missing, error } = countCheck(targets, rendered);
  assert.deepEqual(missing, []);
  assert.equal(error, null);
  assert.equal(runStatus({ ...clean(), missing }), 0);
});

test('the count check names each requested board without a PNG and fails the run', async () => {
  const targets = await m1Targets();
  assert.ok(targets.length > 3);
  const lost = [targets[0].id, targets[2].id];
  const rendered = new Map(targets.filter((t) => !lost.includes(t.id)).map((t) => [t.id, { id: t.id }]));
  const { missing, error } = countCheck(targets, rendered);
  assert.deepEqual(missing, lost);
  assert.equal(error, `NO PNG for 2 of ${targets.length} board(s): ${lost.join(' ')}`);
  assert.equal(runStatus({ ...clean(), missing }), 1);
});

test('the count check counts only the requested boards', () => {
  const rendered = new Set(['a1-1', 'a1-2']);
  assert.deepEqual(countCheck([{ id: 'a1-1' }], rendered), { missing: [], error: null });
  assert.deepEqual(countCheck([{ id: 'a1-3' }], rendered).missing, ['a1-3']);
});

test('a failed board, a file missing from design/ or a second render that differs fails the run', () => {
  assert.equal(runStatus({ ...clean(), failures: [{ id: 'a1-1', file: 'x.dc.html', reason: 'boom' }] }), 1);
  assert.equal(runStatus({ ...clean(), misses: ['/missing.css'] }), 1);
  assert.equal(runStatus({ ...clean(), mismatches: [{ id: 'a1-1', reason: '3 pixel(s) differ' }] }), 1);
});

test('a blocked request to another host fails the run, even when every board has its PNG', async () => {
  const router = await createOfflineRouter({ designDir: DESIGN_DIR, modulesDir: MODULES_DIR, origin: ORIGIN });
  const boardViolations = [];
  let handler;
  await router.install(
    {
      route: async (_pattern, h) => {
        handler = h;
      },
    },
    (v) => boardViolations.push(v),
  );
  const request = async (url) => {
    let action;
    await handler({
      request: () => ({ url: () => url, method: () => 'GET' }),
      continue: async () => {
        action = 'continue';
      },
      fulfill: async () => {
        action = 'fulfill';
      },
      abort: async () => {
        action = 'abort';
      },
    });
    return action;
  };

  // The design server's own requests are not violations.
  assert.equal(await request(`${ORIGIN}/support.js`), 'continue');
  assert.equal(runStatus({ ...clean(), violations: router.violations }), 0);

  assert.equal(await request('https://example.com/tracker.js'), 'abort');
  assert.equal(router.violations.length, 1);
  assert.equal(router.violations[0].url, 'https://example.com/tracker.js');
  // The board whose page asked for it hears of it too (renderBoard fails that board).
  assert.deepEqual(boardViolations, router.violations);
  assert.equal(runStatus({ ...clean(), violations: router.violations }), 1);
});
