import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  BOARD_LANGS,
  CAPTURE_OVERRIDES,
  EXPECTED_BOARD_COUNT,
  domId,
  expandTargets,
  expectedLang,
  langsSet,
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

test('the sets: 23 boards for M1, the 43 M2 boards, and the boards with a language switch', async () => {
  const list = await loadBoards(path.join(TOOL_DIR, 'boards.json'));
  // The 13 M1 artboards, the 5 boards compared for the shell and the languages, and the 5 M1
  // build boards of export 519d42a.
  assert.equal(list.sets.m1.length, 23);
  assert.equal(new Set(list.sets.m1).size, 23);
  for (const id of ['a1-2c-m1', 'a1-5-m1', 'a11-1-m1', 'a11-1w-m1', 'a11-1h-m1']) assert.ok(list.sets.m1.includes(id), id);
  assert.equal(list.sets.m2.length, 43);
  assert.equal(new Set(list.sets.m2).size, 43);
  // Every board of export 519d42a but the region-format table has the switch.
  assert.equal(list.sets.langs.length, 29);
  assert.ok(!list.sets.langs.includes('a12-0'));
  assert.deepEqual(list.sets.langs, langsSet(list.boards));
  for (const b of list.boards) assert.deepEqual(b.langs, list.sets.langs.includes(b.id) ? [...BOARD_LANGS] : undefined, b.id);
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

test('validation compares the languages and accepts variant ids in sets', () => {
  const scanned = [
    { id: 'a1-1', file: 'x.dc.html', capture: 'fm-root', langs: ['tr', 'ar'] },
    { id: 'a1-2', file: 'x.dc.html', capture: 'fm-root' },
  ];
  const list = {
    boards: [
      { id: 'a1-1', file: 'x.dc.html', capture: 'fm-root' },
      { id: 'a1-2', file: 'x.dc.html', capture: 'fm-root' },
    ],
    pages: [],
    sets: { m1: ['a1-1.tr', 'a1-2.tr'] },
  };
  const problems = validateBoards(list, scanned).join('\n');
  assert.match(problems, /a1-1: boards\.json says x\.dc\.html \/ fm-root \/ langs none, design says x\.dc\.html \/ fm-root \/ langs tr,ar/);
  assert.match(problems, /set m1: unknown id a1-1\.tr/);
  assert.match(problems, /set m1: unknown id a1-2\.tr/);
  assert.match(problems, /set langs must list the 1 boards with a language switch/);
  list.boards[0].langs = ['tr', 'ar'];
  list.sets = { m1: ['a1-1.tr'], langs: ['a1-1'] };
  assert.deepEqual(validateBoards(list, scanned).filter((p) => !p.includes('expected')), []);
});

test('each language becomes a render target of its own', () => {
  const board = { id: 'a1-9c', file: 'x.dc.html', capture: 'fm-root', langs: ['tr', 'ar'] };
  const plain = { id: 'f1', file: 'y.dc.html', capture: 'element' };
  const targets = expandTargets([board, plain]);
  assert.deepEqual(targets.map((t) => [t.id, domId(t), t.lang, expectedLang(t)]), [
    ['a1-9c', 'a1-9c', undefined, 'en'],
    ['a1-9c.tr', 'a1-9c', 'tr', 'tr'],
    ['a1-9c.ar', 'a1-9c', 'ar', 'ar'],
    ['f1', 'f1', undefined, null],
  ]);
  // A variant is captured from the board's own element.
  assert.equal(selectorFor(targets[1]), '[id="a1-9c"].fm-root, [id="a1-9c"] .fm-root');
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
