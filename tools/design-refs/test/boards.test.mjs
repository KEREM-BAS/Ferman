import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  CAPTURE_OVERRIDES,
  EXPECTED_BOARD_COUNT,
  loadBoards,
  scanDesign,
  selectorFor,
  unionBox,
  validateBoards,
} from '../boards.mjs';

const TOOL_DIR = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const DESIGN_DIR = path.join(TOOL_DIR, '..', '..', 'design');

test('boards.json matches the design files', async () => {
  const list = await loadBoards(path.join(TOOL_DIR, 'boards.json'));
  const scanned = await scanDesign(DESIGN_DIR);
  assert.deepEqual(validateBoards(list, scanned), []);
  assert.equal(list.boards.length, EXPECTED_BOARD_COUNT);
  assert.equal(list.boards.filter((b) => b.capture === 'element').length, 10, '9 fix boards and a12-0');
  for (const [id, capture] of Object.entries(CAPTURE_OVERRIDES)) {
    assert.equal(list.boards.find((b) => b.id === id)?.capture, capture, id);
  }
  for (const b of [...list.boards, ...list.pages]) assert.ok(existsSync(path.join(DESIGN_DIR, b.file)), b.file);
});

test('the M1 set names the 18 M1 boards', async () => {
  const list = await loadBoards(path.join(TOOL_DIR, 'boards.json'));
  assert.equal(list.sets.m1.length, 18);
  assert.equal(new Set(list.sets.m1).size, 18);
});

test('validation reports missing, extra and moved boards', () => {
  const scanned = [
    { id: 'a1-1', file: 'x.dc.html', capture: 'fm-root' },
    { id: 'a1-2', file: 'x.dc.html', capture: 'fm-root' },
  ];
  const list = {
    boards: [
      { id: 'a1-1', file: 'y.dc.html', capture: 'fm-root' },
      { id: 'a9-9', file: 'x.dc.html', capture: 'fm-root' },
    ],
    pages: [],
    sets: { m1: ['a1-1', 'zz'] },
  };
  const problems = validateBoards(list, scanned).join('\n');
  assert.match(problems, /a1-2 \(x\.dc\.html\) is missing/);
  assert.match(problems, /a9-9 is in boards\.json but not/);
  assert.match(problems, /a1-1: boards\.json says y\.dc\.html/);
  assert.match(problems, /set m1: unknown id zz/);
});

test('capture selectors follow the capture rule', () => {
  assert.equal(selectorFor({ id: 'f4a', capture: 'element' }), '[id="f4a"]');
  assert.equal(selectorFor({ id: 'a2-3p', capture: 'fm-root' }), '[id="a2-3p"].fm-root, [id="a2-3p"] .fm-root');
  assert.equal(selectorFor({ id: 'a2-3m', capture: 'fm-roots' }), '[id="a2-3m"] .fm-root');
  assert.equal(selectorFor({ id: 'ds-additions', capture: 'page' }), '#dc-root .fm-root');
  assert.throws(() => selectorFor({ id: 'x', capture: 'other' }), /unknown capture mode/);
});

test('the union box holds every box', () => {
  assert.deepEqual(unionBox([{ x: 10, y: 5, width: 216, height: 752 }]), { x: 10, y: 5, width: 216, height: 752 });
  assert.deepEqual(
    unionBox([
      { x: 10, y: 5, width: 216, height: 752 },
      { x: 254, y: 5, width: 216, height: 700 },
      { x: 498, y: 0, width: 216, height: 760 },
    ]),
    { x: 10, y: 0, width: 704, height: 760 },
  );
});
