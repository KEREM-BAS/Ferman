import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { loadBoards, scanDesign } from '../boards.mjs';
import { UsageError } from '../cli.mjs';
import {
  EXIT,
  GOLDEN_NAME,
  InputError,
  compareImages,
  compareMain,
  cropImage,
  encodePng,
  flattenOnWhite,
  loadMap,
  meanSsim,
  parseCompareCli,
  readPng,
  renderReport,
  runComparison,
  sideBySide,
  validateMap,
} from '../compare.mjs';

const TOOL_DIR = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const REPO_DIR = path.resolve(TOOL_DIR, '..', '..');
const DESIGN_DIR = path.join(REPO_DIR, 'design');
const MAP_FILE = path.join(TOOL_DIR, 'compare-map.json');

const WHITE = [255, 255, 255, 255];
const BLACK = [0, 0, 0, 255];

/** A solid image. */
function solid(width, height, rgba = WHITE) {
  const data = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i += 1) data.set(rgba, i * 4);
  return { width, height, data };
}

/** A copy of [img] with the pixel at x, y set to rgba. */
function withPixel(img, x, y, rgba) {
  const data = Buffer.alloc(img.data.length);
  data.set(img.data);
  data.set(rgba, (y * img.width + x) * 4);
  return { width: img.width, height: img.height, data };
}

/** A deterministic pattern with edges and gradients, so SSIM has structure to look at. */
function pattern(width, height) {
  const img = solid(width, height);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const v = (x * 7 + y * 13) % 256;
      img.data.set([v, (v * 3) % 256, x % 2 ? 40 : 220, 255], (y * width + x) * 4);
    }
  }
  return img;
}

const pixel = (img, x, y) => [...img.data.subarray((y * img.width + x) * 4, (y * img.width + x) * 4 + 4)];

async function boardIds() {
  const list = await loadBoards(path.join(TOOL_DIR, 'boards.json'));
  return new Set([...list.boards, ...list.pages].map((b) => b.id));
}

let base;

before(async () => {
  base = await mkdtemp(path.join(os.tmpdir(), 'design-refs-compare-'));
});

after(async () => {
  await rm(base, { recursive: true, force: true });
});

// --- The map --------------------------------------------------------------------------------

test('the map parses and every board in it exists in the design export', async () => {
  const map = await loadMap(MAP_FILE, { boardIds: await boardIds() });
  assert.deepEqual(map.goldenSize, { width: 1440, height: 900 });
  const scanned = new Set((await scanDesign(DESIGN_DIR)).map((b) => b.id));
  for (const pair of map.pairs) assert.ok(scanned.has(pair.board), `${pair.id}: ${pair.board} is not a board of design/`);
  for (const pair of map.pairs.filter((p) => p.golden)) assert.match(pair.golden, GOLDEN_NAME, pair.id);
});

test('the map covers the M1 set, and CI renders every board it names', async () => {
  const list = await loadBoards(path.join(TOOL_DIR, 'boards.json'));
  const map = await loadMap(MAP_FILE, { boardIds: await boardIds() });
  const boards = new Set(map.pairs.map((p) => p.board));
  for (const id of list.sets.m1) assert.ok(boards.has(id), `${id} of @m1 has no pair`);
  for (const id of boards) assert.ok(list.sets.m1.includes(id), `${id} is not in @m1, which CI renders`);
  assert.deepEqual(
    map.pairs.filter((p) => p.notCompared).map((p) => p.board),
    ['a12-2b', 'a12-2d'],
  );
  for (const pair of map.pairs.filter((p) => p.notCompared)) assert.match(pair.notCompared, /German/);
});

test('the map pairs the boards with the goldens drawn from them', async () => {
  const map = await loadMap(MAP_FILE, { boardIds: await boardIds() });
  const golden = Object.fromEntries(map.pairs.map((p) => [p.id, p.golden]));
  assert.equal(golden['a1-1'], 'language_picker_mac_light_en.png');
  assert.equal(golden['a12-2a'], 'start_mac_light_ar.png');
  assert.equal(golden['a12-2c'], 'settings_language_mac_light_ar.png');
  assert.equal(golden['a11-1w'], 'settings_general_win_light_en.png');
  assert.equal(golden['f6a'], 'shell_edit_win_light_en.png');
  assert.equal(golden['a2-1b'], 'shell_view_mac_light_en.png');
  assert.equal(golden['a3-1d'], 'shell_edit_mac_dark_en.png');
  // The fix boards are larger than one window: each is cropped to a window or a strip of one.
  for (const id of ['f6-mac', 'f6-win', 'f6a']) {
    const pair = map.pairs.find((p) => p.id === id);
    assert.ok(pair.crop && pair.cropSource, `${id} needs a crop and its source`);
  }
});

test('map validation reports every problem', async () => {
  const ids = await boardIds();
  const good = { goldenSize: { width: 16, height: 8 }, pairs: [{ board: 'a1-1', golden: 'language_picker_mac_light_en.png' }] };
  assert.equal(validateMap(good, { boardIds: ids }).pairs[0].id, 'a1-1');
  const bad = {
    goldenSize: { width: 16, height: 8 },
    pairs: [
      { board: 'a0-0', golden: 'language_picker_mac_light_en.png' },
      { board: 'a1-1', golden: 'language_picker_linux_light_en.png' },
      { board: 'a1-1', golden: 'start_mac_light_en.png' },
      { board: 'a1-5', golden: 'start_mac_light_de.png', colour: 'x' },
      { board: 'f6', id: 'f6-a', golden: 'shell_edit_mac_light_en.png', crop: { x: 0, y: 0, width: 10, height: 8 }, cropSource: 'x' },
      { board: 'f6', id: 'f6-b', golden: 'shell_edit_mac_light_en.png', crop: { x: 0, y: 0, width: 16, height: 8 } },
      { board: 'f6a', golden: 'shell_edit_win_light_en.png', masks: [{ label: 'canvas', x: 10, y: 0, width: 10, height: 8 }] },
      { board: 'a11-1', golden: 'settings_general_mac_light_en.png', masks: [{ x: 0, y: 0, width: 1, height: 1 }] },
      { board: 'a12-2b' },
      { board: 'a12-2d', notCompared: '' },
      { board: 'a11-1w', golden: 'settings_general_win_light_en.png', notCompared: 'both' },
      { board: 'a11-1b', golden: 'settings_language_mac_light_en.png', goldenCrop: { x: 8, y: 0, width: 16, height: 8 } },
    ],
  };
  assert.throws(
    () => validateMap(bad, { boardIds: ids }),
    (error) => {
      assert.ok(error instanceof InputError);
      const m = error.message;
      for (const expected of [
        /unknown board id "a0-0"/,
        /golden "language_picker_linux_light_en\.png" is not/,
        /duplicate id "a1-1"/,
        /start_mac_light_de\.png/,
        /unknown key "colour"/,
        /the crop is 10 × 8 but the golden is 16 × 8/,
        /\(f6-b\): a crop needs "cropSource"/,
        /masks\[0\] lies outside the compared 16 × 8/,
        /\(a11-1\)\.masks\[0\]: needs a "label"/,
        /\(a12-2b\): give either "golden" or "notCompared"/,
        /\(a12-2d\): "notCompared" needs the reason/,
        /\(a11-1w\): give either/,
        /goldenCrop lies outside the 16 × 8 golden/,
      ]) {
        assert.match(m, expected);
      }
      return true;
    },
  );
  assert.throws(() => validateMap({ pairs: [] }, { boardIds: ids }), /goldenSize[\s\S]*"pairs" must be a non-empty array/);
  // Broken rectangles are reported, never measured.
  const broken = {
    goldenSize: { width: 16, height: 8 },
    pairs: [
      { board: 'f6', golden: 'shell_edit_mac_light_en.png', crop: null, cropSource: 'x', goldenCrop: 'top', masks: [null, { x: 0, y: 0, width: 1, height: 1, label: 'm' }] },
      { board: 'f6a', golden: 'shell_edit_win_light_en.png', crop: { x: 0, y: 0, width: 16, height: 8, label: 'no' }, cropSource: 'x' },
    ],
  };
  assert.throws(
    () => validateMap(broken, { boardIds: ids }),
    (error) => {
      assert.ok(error instanceof InputError);
      assert.match(error.message, /\(f6\)\.crop must be an object/);
      assert.match(error.message, /\(f6\)\.goldenCrop must be an object/);
      assert.match(error.message, /\(f6\)\.masks\[0\] must be an object/);
      assert.match(error.message, /\(f6a\)\.crop: unknown key "label"/);
      return true;
    },
  );
});

test('an unreadable map is an input error', async () => {
  const file = path.join(base, 'broken-map.json');
  await writeFile(file, '{ not json');
  await assert.rejects(loadMap(file, { boardIds: await boardIds() }), InputError);
  await assert.rejects(loadMap(path.join(base, 'no-map.json'), { boardIds: await boardIds() }), InputError);
});

// --- Images and scores ----------------------------------------------------------------------

test('cropping copies the rectangle and refuses one outside the image', () => {
  const img = pattern(6, 5);
  const c = cropImage(img, { x: 2, y: 1, width: 3, height: 2 });
  assert.equal(c.width, 3);
  assert.equal(c.height, 2);
  for (let y = 0; y < 2; y += 1) for (let x = 0; x < 3; x += 1) assert.deepEqual(pixel(c, x, y), pixel(img, x + 2, y + 1));
  assert.deepEqual(cropImage(img, { x: 0, y: 0, width: 6, height: 5 }).data, img.data);
  assert.throws(() => cropImage(img, { x: 4, y: 0, width: 3, height: 1 }), RangeError);
  assert.throws(() => cropImage(img, { x: 0, y: 4, width: 1, height: 2 }), RangeError);
});

test('identical images score 0', () => {
  const a = pattern(40, 30);
  const s = compareImages(a, { ...a, data: Buffer.from(a.data) });
  assert.equal(s.differing, 0);
  assert.equal(s.diffShare, 0);
  assert.equal(s.structDiff, 0);
  assert.equal(s.comparedPixels, 1200);
  assert.equal(meanSsim(a, a), 1);
});

test('a one-pixel change counts one pixel', () => {
  const ref = solid(20, 10);
  const s = compareImages(ref, withPixel(ref, 5, 5, BLACK));
  assert.equal(s.differing, 1);
  assert.equal(s.diffShare, 1 / 200);
  assert.ok(s.structDiff > 0 && s.structDiff < 0.5, `1 − SSIM ${s.structDiff}`);
  assert.deepEqual(pixel(s.diff, 5, 5), [255, 0, 0, 255], 'drawn red in the diff');
  // A grey pixel is a smaller structural change than a black one.
  const grey = compareImages(ref, withPixel(ref, 5, 5, [128, 128, 128, 255]));
  assert.equal(grey.differing, 1);
  assert.ok(grey.structDiff < s.structDiff);
});

test('a change below the threshold is not counted', () => {
  const ref = solid(20, 10, [200, 200, 200, 255]);
  const s = compareImages(ref, withPixel(ref, 5, 5, [202, 202, 202, 255]));
  assert.equal(s.differing, 0);
  assert.ok(s.structDiff > 0 && s.structDiff < 1e-3, `1 − SSIM ${s.structDiff}`);
  // With threshold 0 every changed pixel counts.
  assert.equal(compareImages(ref, withPixel(ref, 5, 5, [202, 202, 202, 255]), { threshold: 0 }).differing, 1);
});

test('masked pixels count in neither score', () => {
  const ref = pattern(20, 10);
  const mask = { label: 'canvas', x: 4, y: 4, width: 3, height: 3 };
  const s = compareImages(ref, withPixel(ref, 5, 5, BLACK), { masks: [mask] });
  assert.equal(s.differing, 0);
  assert.equal(s.structDiff, 0);
  assert.equal(s.comparedPixels, 200 - 9);
  const [r, g, b] = pixel(s.diff, 5, 5);
  assert.ok(r === g && g === b && r > 200, 'hatched in the diff');
  // The pixel next to the mask still counts.
  assert.equal(compareImages(ref, withPixel(ref, 7, 5, BLACK), { masks: [mask] }).differing, 1);
});

test('images of different sizes are refused', () => {
  assert.throws(() => compareImages(solid(4, 4), solid(4, 5)), /sizes differ/);
});

test('transparent pixels are composited over white', () => {
  const img = solid(2, 1, [0, 0, 0, 0]);
  img.data.set([0, 0, 0, 128], 4);
  flattenOnWhite(img);
  assert.deepEqual(pixel(img, 0, 0), [255, 255, 255, 255]);
  assert.deepEqual(pixel(img, 1, 0), [127, 127, 127, 255]);
});

test('PNG round trip, and the side-by-side image is reference | golden | diff', async () => {
  const ref = pattern(10, 6);
  const file = path.join(base, 'round.png');
  await writeFile(file, encodePng(ref));
  assert.deepEqual((await readPng(file)).data, ref.data);

  const golden = solid(10, 6, BLACK);
  const diff = solid(10, 6, [255, 0, 0, 255]);
  const side = sideBySide(ref, golden, diff, [{ label: 'm', x: 0, y: 0, width: 4, height: 4 }]);
  assert.equal(side.width, 10 * 3 + 16 * 2);
  assert.equal(side.height, 6);
  assert.deepEqual(pixel(side, 5, 5), pixel(ref, 5, 5));
  assert.deepEqual(pixel(side, 10, 0), [128, 128, 128, 255], 'gap');
  assert.deepEqual(pixel(side, 26 + 5, 5), BLACK);
  assert.deepEqual(pixel(side, 52 + 5, 5), [255, 0, 0, 255]);
  assert.deepEqual(pixel(side, 0, 0), [255, 0, 255, 255], 'mask outlined on the reference');
  assert.deepEqual(pixel(side, 26, 0), [255, 0, 255, 255], 'mask outlined on the golden');
  assert.deepEqual(pixel(side, 52, 0), [255, 0, 0, 255], 'not on the diff');
});

// --- A run and its report -------------------------------------------------------------------

/** Fixture folders: references, goldens and a map with one pair of every kind. */
async function fixture(name) {
  const dir = path.join(base, name);
  const refs = path.join(dir, 'refs');
  const goldens = path.join(dir, 'goldens');
  const out = path.join(dir, 'out');
  for (const d of [refs, goldens, out]) await mkdir(d, { recursive: true });
  const window = pattern(16, 8);
  // f6: a board larger than the window, with the window at 3, 5.
  const board = solid(30, 20, [232, 229, 223, 255]);
  for (let y = 0; y < 8; y += 1) board.data.set(window.data.subarray(y * 64, (y + 1) * 64), ((y + 5) * 30 + 3) * 4);
  await writeFile(path.join(refs, 'f6.png'), encodePng(board));
  await writeFile(path.join(refs, 'a1-1.png'), encodePng(window));
  await writeFile(path.join(refs, 'a1-5.png'), encodePng(window));
  await writeFile(path.join(refs, 'a11-1w.png'), encodePng(window));
  await writeFile(path.join(refs, 'a11-1b.png'), encodePng(window));
  await writeFile(path.join(goldens, 'language_picker_mac_light_en.png'), encodePng(window));
  await writeFile(path.join(goldens, 'start_mac_light_en.png'), encodePng(withPixel(window, 2, 3, BLACK)));
  await writeFile(path.join(goldens, 'shell_edit_win_light_en.png'), encodePng(window));
  await writeFile(path.join(goldens, 'settings_general_win_light_en.png'), encodePng(solid(10, 8)));
  await writeFile(path.join(goldens, 'settings_language_mac_light_en.png'), 'not a png');
  await writeFile(path.join(goldens, 'icons.png'), encodePng(solid(2, 2)));
  // A stale image of a pair that has no golden this time.
  await writeFile(path.join(out, 'a11-1.side.png'), 'stale');
  const map = {
    goldenSize: { width: 16, height: 8 },
    pairs: [
      { board: 'a1-1', golden: 'language_picker_mac_light_en.png', note: 'identical' },
      { board: 'a1-5', golden: 'start_mac_light_en.png', note: 'one pixel | piped' },
      { board: 'f6', id: 'f6-win', golden: 'shell_edit_win_light_en.png', crop: { x: 3, y: 5, width: 16, height: 8 }, cropSource: 'fixture' },
      { board: 'a11-1', golden: 'settings_general_mac_light_en.png' },
      { board: 'a12-2b', notCompared: 'German board: no German golden in M1' },
      { board: 'a11-1w', golden: 'settings_general_win_light_en.png' },
      { board: 'a11-1b', golden: 'settings_language_mac_light_en.png' },
      { board: 'a12-2c', golden: 'settings_language_mac_light_ar.png', masks: [{ label: 'canvas', x: 0, y: 0, width: 4, height: 4 }] },
    ],
  };
  const mapFile = path.join(dir, 'map.json');
  await writeFile(mapFile, JSON.stringify(map));
  return { dir, refs, goldens, out, mapFile, map: validateMap(map, { boardIds: await boardIds() }) };
}

test('a run gives one row per pair; missing and broken inputs become rows, not crashes', async () => {
  const f = await fixture('run');
  const rows = await runComparison(f.map, { refsDir: f.refs, goldensDir: f.goldens, outDir: f.out });
  const by = Object.fromEntries(rows.map((r) => [r.pair.id, r]));
  assert.deepEqual(
    rows.map((r) => r.pair.id),
    f.map.pairs.map((p) => p.id),
  );
  assert.equal(by['a1-1'].result, 'compared');
  assert.equal(by['a1-1'].scores.differing, 0);
  assert.equal(by['a1-5'].result, 'compared');
  assert.equal(by['a1-5'].scores.differing, 1);
  assert.equal(by['a1-5'].scores.diffShare, 1 / 128);
  assert.equal(by['f6-win'].result, 'compared');
  assert.equal(by['f6-win'].scores.differing, 0, 'the crop finds the window');
  assert.equal(by['a11-1'].result, 'missing');
  assert.equal(by['a11-1'].detail, 'no reference and no golden');
  assert.equal(by['a12-2b'].result, 'not compared');
  assert.equal(by['a11-1w'].result, 'error');
  assert.match(by['a11-1w'].detail, /the golden is 10 × 8, not 16 × 8/);
  assert.equal(by['a11-1b'].result, 'error');
  assert.match(by['a11-1b'].detail, /^golden: /);
  assert.equal(by['a12-2c'].result, 'missing');
  assert.equal(by['a12-2c'].detail, 'no reference and no golden');

  for (const id of ['a1-1', 'a1-5', 'f6-win']) {
    assert.ok(existsSync(path.join(f.out, `${id}.diff.png`)), id);
    const side = await readPng(path.join(f.out, `${id}.side.png`));
    assert.equal(side.width, 16 * 3 + 32);
  }
  assert.equal(existsSync(path.join(f.out, 'a11-1.side.png')), false, 'stale image removed');
  assert.equal(existsSync(path.join(f.out, 'a11-1w.diff.png')), false);
});

test('a missing reference and a crop outside the board are reported', async () => {
  const f = await fixture('refs');
  await rm(path.join(f.refs, 'a1-1.png'));
  const map = validateMap(
    {
      goldenSize: { width: 16, height: 8 },
      pairs: [
        { board: 'a1-1', golden: 'language_picker_mac_light_en.png' },
        { board: 'f6', golden: 'shell_edit_win_light_en.png', crop: { x: 20, y: 5, width: 16, height: 8 }, cropSource: 'fixture' },
      ],
    },
    { boardIds: await boardIds() },
  );
  const rows = await runComparison(map, { refsDir: f.refs, goldensDir: f.goldens, outDir: f.out });
  assert.equal(rows[0].result, 'missing');
  assert.equal(rows[0].detail, 'no reference');
  assert.equal(rows[1].result, 'error');
  assert.match(rows[1].detail, /crop 16 × 8 at 20, 5 lies outside the 30 × 20 image/);
});

test('report.md lists every pair with its scores, images and notes', async () => {
  const f = await fixture('report');
  const rows = await runComparison(f.map, { refsDir: f.refs, goldensDir: f.goldens, outDir: f.out });
  const report = renderReport(rows, {
    threshold: 0.1,
    refsLabel: 'build/design-refs',
    goldensLabel: 'app/test/goldens/goldens/linux',
    goldenFiles: ['icons.png', 'language_picker_mac_light_en.png', 'start_mac_light_ar.png'],
    runUrl: 'https://github.com/o/r/actions/runs/1',
    pixelmatchVersion: '7.2.0',
  });
  assert.match(report, /\*\*Summary:\*\* 8 pairs: 3 compared, 2 missing, 2 with errors, 1 not compared\. Differing pixels: median 0\.00 %, highest 0\.78 % \(`a1-5`\)\./);
  assert.match(report, /2 of the golden matrix; 1 of them have no pair/);
  assert.match(report, /artifact of \[this run\]\(https:\/\/github\.com\/o\/r\/actions\/runs\/1\)/);
  const tableRows = report.split('\n').filter((l) => l.startsWith('| `'));
  assert.equal(tableRows.length, f.map.pairs.length);
  for (const pair of f.map.pairs) assert.ok(tableRows.some((l) => l.startsWith(`| \`${pair.id}\` |`)), pair.id);
  const row = (id) => tableRows.find((l) => l.startsWith(`| \`${id}\` |`));
  assert.match(row('a1-5'), /\| compared \| 0\.78 % \(1 px\) \| 0\.\d{4} \| `a1-5\.side\.png`, `a1-5\.diff\.png` \| one pixel \\\| piped \|$/);
  assert.match(row('f6-win'), /Board crop: 16 × 8 at 3, 5\./);
  assert.match(row('a12-2c'), /missing: no reference and no golden .*Masked: canvas 4 × 4 at 0, 0\./);
  assert.match(row('a12-2b'), /\| not compared \| – \| – \| – \| German board: no German golden in M1 \|$/);
  assert.match(row('a11-1w'), /\| error: the golden is 10 × 8, not 16 × 8 \|/);
  for (const l of tableRows) assert.equal(l.split(/(?<!\\)\|/).length, 10, `8 cells: ${l}`);

  const none = renderReport([], { threshold: 0.1, refsLabel: 'r', goldensLabel: 'g', goldenFiles: null });
  assert.match(none, /\*\*Summary:\*\* 0 pairs: 0 compared/);
  assert.match(none, /`g` does not exist yet/);
});

test('with the real map and no images every pair is a row: missing or not compared', async () => {
  const map = await loadMap(MAP_FILE, { boardIds: await boardIds() });
  const empty = path.join(base, 'empty');
  await mkdir(empty, { recursive: true });
  const rows = await runComparison(map, { refsDir: empty, goldensDir: path.join(empty, 'none'), outDir: path.join(base, 'empty-out') });
  assert.equal(rows.length, map.pairs.length);
  for (const r of rows) assert.equal(r.result, r.pair.notCompared ? 'not compared' : 'missing', r.pair.id);
  const report = renderReport(rows, { threshold: 0.1, refsLabel: 'r', goldensLabel: 'g', goldenFiles: null });
  for (const pair of map.pairs) assert.ok(report.includes(`| \`${pair.id}\` | \`${pair.board}\` |`), pair.id);
});

// --- The command ----------------------------------------------------------------------------

test('compare options: defaults and usage errors', () => {
  const defaults = { refs: '/r', goldens: '/g', out: '/o', map: '/m.json' };
  const o = parseCompareCli([], defaults);
  assert.deepEqual(o, { refs: '/r', goldens: '/g', out: '/o', map: '/m.json', threshold: 0.1, help: false });
  assert.equal(parseCompareCli(['--threshold', '0', '--out', 'x'], defaults).out, path.resolve('x'));
  assert.equal(parseCompareCli(['--threshold', '0'], defaults).threshold, 0);
  for (const argv of [['--threshold', '1.5'], ['--threshold', 'x'], ['--threshold', ''], ['--nope'], ['extra'], ['--out', '']]) {
    assert.throws(() => parseCompareCli(argv, defaults), UsageError, argv.join(' '));
  }
});

test('compare exit codes: 0 with goldens missing, 64 for usage, 66 for unreadable inputs', async () => {
  const f = await fixture('main');
  const lines = [];
  const run = (argv) => compareMain(argv, { repoDir: REPO_DIR, toolDir: TOOL_DIR, log: (l) => lines.push(l), error: (l) => lines.push(l), env: {} });
  const io = ['--refs', f.refs, '--map', f.mapFile, '--out', f.out];

  assert.equal(await run([...io, '--goldens', f.goldens]), EXIT.ok);
  const report = await readFile(path.join(f.out, 'report.md'), 'utf8');
  assert.match(report, /\*\*Summary:\*\* 8 pairs: 3 compared/);
  assert.doesNotMatch(report, /this run/, 'no run link outside GitHub Actions');

  lines.length = 0;
  assert.equal(await run([...io, '--goldens', path.join(f.dir, 'no-goldens')]), EXIT.ok);
  assert.ok(lines.some((l) => /does not exist; every pair is reported missing/.test(l)));
  assert.match(await readFile(path.join(f.out, 'report.md'), 'utf8'), /\*\*Summary:\*\* 8 pairs: 0 compared, 7 missing/);

  assert.equal(await run(['--nope']), EXIT.usage);
  assert.equal(await run([...io, '--threshold', '2']), EXIT.usage);
  assert.equal(await run(['--refs', f.refs, '--map', f.mapFile, '--out', path.join(DESIGN_DIR, 'compare')]), EXIT.usage);
  assert.equal(existsSync(path.join(DESIGN_DIR, 'compare')), false);
  assert.equal(await run([...io, '--goldens', f.goldens, '--out', path.join(f.goldens, 'out')]), EXIT.usage);
  assert.equal(await run(['--refs', f.refs, '--map', path.join(f.dir, 'no-map.json'), '--out', f.out]), EXIT.noInput);
  assert.equal(await run(['--refs', path.join(f.dir, 'no-refs'), '--map', f.mapFile, '--out', f.out]), EXIT.noInput);
  assert.equal(await run(['--help']), EXIT.ok);
  assert.ok(lines.some((l) => l.startsWith('Usage: node tools/design-refs compare')));
});

test('node tools/design-refs compare dispatches to compare', () => {
  const index = path.join(TOOL_DIR, 'index.mjs');
  const help = spawnSync(process.execPath, [index, 'compare', '--help'], { encoding: 'utf8' });
  assert.equal(help.status, 0, help.stderr);
  assert.match(help.stdout, /^Usage: node tools\/design-refs compare/);
  const bad = spawnSync(process.execPath, [index, 'compare', '--nope'], { encoding: 'utf8' });
  assert.equal(bad.status, 64);
  assert.match(bad.stderr, /Unknown option '--nope'/);
});
