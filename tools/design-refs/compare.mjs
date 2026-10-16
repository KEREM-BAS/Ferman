// The golden-versus-reference comparison (ROADMAP §5 step 11): lines up each app golden with the
// render of the board it was built from and reports two difference scores per pair, with a diff
// image and a side-by-side image. The scores are informative; nothing here fails on them.
//
// `node tools/design-refs compare --help` lists the options; README.md explains the scores.

import { existsSync } from 'node:fs';
import { mkdir, readdir, readFile, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { parseArgs } from 'node:util';

import pixelmatch from 'pixelmatch';
import { PNG } from 'pngjs';

import { loadBoards } from './boards.mjs';
import { UsageError, isInsideDir } from './cli.mjs';

/** The screens of the golden matrix (phase K1), in the order of the contract. */
export const GOLDEN_SCREENS = [
  'language_picker',
  'welcome_privacy',
  'welcome_free',
  'start',
  'settings_general',
  'settings_language',
  'shell_view',
  'shell_edit',
  'shell_comment',
  'shell_fill_sign',
  'shell_organize',
  'shell_convert',
  'shell_protect',
  'shell_tools',
];

/** A golden's file name: `<screen>_<chrome>_<theme>_<lang>.png`. */
export const GOLDEN_NAME = new RegExp(`^(${GOLDEN_SCREENS.join('|')})_(mac|win)_(light|dark)_(en|tr|ar)\\.png$`);

/** pixelmatch's own default: the YIQ colour distance, from 0 to 1, a pixel may differ by unseen. */
export const DEFAULT_THRESHOLD = 0.1;

/** Exit codes: sysexits.h EX_USAGE and EX_NOINPUT; 1 for anything unexpected. */
export const EXIT = { ok: 0, failure: 1, usage: 64, noInput: 66 };

/** An input that cannot be read at all: the map, or the folder of references. */
export class InputError extends Error {}

const PAIR_KEYS = new Set(['id', 'board', 'golden', 'notCompared', 'crop', 'cropSource', 'goldenCrop', 'masks', 'note']);
const PAIR_ID = /^[a-z0-9][a-z0-9-]*$/;

/** Fill of masked pixels in the diff image: grey diagonal stripes. */
const HATCH = [
  [214, 214, 214],
  [236, 236, 236],
];
/** Outline of a masked area on the reference and golden panels of the side-by-side image. */
const MASK_OUTLINE = [255, 0, 255];
/** Gap between the panels of the side-by-side image. */
const GAP = { width: 16, colour: [128, 128, 128] };

// ---------------------------------------------------------------------------------------------
// The map

const isInt = (v) => Number.isInteger(v);

/**
 * Problems of a rectangle `{x, y, width, height}` (whole pixels, inside the first quadrant); a
 * mask also carries its `label`.
 */
function rectProblems(rect, where, { label = false } = {}) {
  if (typeof rect !== 'object' || rect === null || Array.isArray(rect)) return [`${where} must be an object`];
  const problems = [];
  const keys = label ? ['x', 'y', 'width', 'height', 'label'] : ['x', 'y', 'width', 'height'];
  for (const key of Object.keys(rect)) if (!keys.includes(key)) problems.push(`${where}: unknown key "${key}"`);
  for (const key of ['x', 'y']) if (!isInt(rect[key]) || rect[key] < 0) problems.push(`${where}.${key} must be a whole number ≥ 0`);
  for (const key of ['width', 'height']) if (!isInt(rect[key]) || rect[key] < 1) problems.push(`${where}.${key} must be a whole number ≥ 1`);
  return problems;
}

const sameSize = (a, b) => a.width === b.width && a.height === b.height;
const size = (s) => `${s.width} × ${s.height}`;

/**
 * Checks a parsed compare map and returns it normalised: every pair with its `id` (the board id
 * unless given) and `masks` (empty unless given).
 *
 * @param {any} data the parsed JSON
 * @param {{boardIds: Set<string>}} known the board ids of boards.json
 * @returns {{goldenSize: {width: number, height: number}, pairs: Array<object>}}
 * @throws {InputError} listing every problem
 */
export function validateMap(data, { boardIds }) {
  const problems = [];
  if (typeof data !== 'object' || data === null || Array.isArray(data)) throw new InputError('the map must be a JSON object');
  const goldenSize = data.goldenSize;
  const sizeProblems = rectProblems({ x: 0, y: 0, ...goldenSize }, 'goldenSize');
  problems.push(...sizeProblems);
  if (!Array.isArray(data.pairs) || data.pairs.length === 0) problems.push('"pairs" must be a non-empty array');
  const pairs = [];
  const ids = new Set();
  for (const [index, raw] of (Array.isArray(data.pairs) ? data.pairs : []).entries()) {
    const where = `pairs[${index}]${typeof raw?.board === 'string' ? ` (${raw.id ?? raw.board})` : ''}`;
    if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
      problems.push(`${where} must be an object`);
      continue;
    }
    for (const key of Object.keys(raw)) if (!PAIR_KEYS.has(key)) problems.push(`${where}: unknown key "${key}"`);
    const pair = { ...raw, id: raw.id ?? raw.board, masks: raw.masks ?? [] };
    if (typeof raw.board !== 'string' || !boardIds.has(raw.board)) problems.push(`${where}: unknown board id ${JSON.stringify(raw.board)}`);
    if (typeof pair.id !== 'string' || !PAIR_ID.test(pair.id)) problems.push(`${where}: the id must match ${PAIR_ID}`);
    else if (ids.has(pair.id)) problems.push(`${where}: duplicate id "${pair.id}" (give each pair of one board its own "id")`);
    ids.add(pair.id);
    if (raw.note !== undefined && typeof raw.note !== 'string') problems.push(`${where}: "note" must be a string`);

    const compared = raw.golden !== undefined && raw.golden !== null;
    if (compared === (typeof raw.notCompared === 'string')) {
      problems.push(`${where}: give either "golden" or "notCompared" (the reason), not both or neither`);
    }
    if (!compared) {
      if (typeof raw.notCompared === 'string' && raw.notCompared.trim() === '') problems.push(`${where}: "notCompared" needs the reason`);
      for (const key of ['crop', 'goldenCrop', 'masks', 'cropSource']) if (raw[key] !== undefined) problems.push(`${where}: "${key}" needs a golden`);
      pairs.push(pair);
      continue;
    }
    if (typeof raw.golden !== 'string' || !GOLDEN_NAME.test(raw.golden)) {
      problems.push(`${where}: golden ${JSON.stringify(raw.golden)} is not <screen>_<mac|win>_<light|dark>_<en|tr|ar>.png`);
    }
    // A rectangle with a problem of its own is not measured against the others.
    const valid = {};
    for (const key of ['crop', 'goldenCrop']) {
      if (raw[key] === undefined) continue;
      const rp = rectProblems(raw[key], `${where}.${key}`);
      problems.push(...rp);
      valid[key] = rp.length === 0;
    }
    if (raw.crop !== undefined && (typeof raw.cropSource !== 'string' || raw.cropSource.trim() === '')) {
      problems.push(`${where}: a crop needs "cropSource", how the rectangle was found`);
    }
    // The frame both images are compared in: the golden's crop, or the whole golden.
    const frame = raw.goldenCrop ?? goldenSize;
    const frameOk = raw.goldenCrop === undefined ? sizeProblems.length === 0 : valid.goldenCrop;
    if (valid.crop && frameOk && !sameSize(raw.crop, frame)) {
      problems.push(`${where}: the crop is ${size(raw.crop)} but the golden${raw.goldenCrop ? "'s crop" : ''} is ${size(frame)}`);
    }
    if (valid.goldenCrop && sizeProblems.length === 0) {
      const g = raw.goldenCrop;
      if (g.x + g.width > goldenSize.width || g.y + g.height > goldenSize.height) problems.push(`${where}: goldenCrop lies outside the ${size(goldenSize)} golden`);
    }
    if (!Array.isArray(pair.masks)) {
      problems.push(`${where}: "masks" must be an array`);
    } else {
      for (const [m, mask] of pair.masks.entries()) {
        const at = `${where}.masks[${m}]`;
        const mp = rectProblems(mask, at, { label: true });
        problems.push(...mp);
        if (mp.length > 0 || !frameOk) continue;
        if (typeof mask.label !== 'string' || mask.label === '') problems.push(`${at}: needs a "label"`);
        if (mask.x + mask.width > frame.width || mask.y + mask.height > frame.height) problems.push(`${at} lies outside the compared ${size(frame)}`);
      }
    }
    pairs.push(pair);
  }
  if (problems.length > 0) throw new InputError(problems.join('\n'));
  return { goldenSize: { width: goldenSize.width, height: goldenSize.height }, pairs };
}

/**
 * Reads and checks a compare map.
 *
 * @param {string} file
 * @param {{boardIds: Set<string>}} known
 */
export async function loadMap(file, known) {
  let data;
  try {
    data = JSON.parse(await readFile(file, 'utf8'));
  } catch (error) {
    throw new InputError(`cannot read the map ${file}: ${error instanceof Error ? error.message : String(error)}`);
  }
  try {
    return validateMap(data, known);
  } catch (error) {
    if (error instanceof InputError) throw new InputError(`${file}:\n${error.message}`);
    throw error;
  }
}

// ---------------------------------------------------------------------------------------------
// Images: `{width, height, data}` with 8-bit RGBA in `data`, always opaque once read.

/**
 * A copy in a buffer of its own. Buffer.from(buffer) can return a slice of Node's shared pool at
 * an offset that is not a multiple of 4, and pixelmatch views its inputs as a Uint32Array.
 */
export function copyPixels(data) {
  const out = Buffer.alloc(data.length);
  out.set(data);
  return out;
}

/** Composites every pixel over white and makes it opaque, in place, as a browser shows it. */
export function flattenOnWhite(img) {
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const a = d[i + 3];
    if (a === 255) continue;
    for (let c = 0; c < 3; c += 1) d[i + c] = Math.round((d[i + c] * a + 255 * (255 - a)) / 255);
    d[i + 3] = 255;
  }
  return img;
}

/** Reads a PNG file (any colour type pngjs decodes) as opaque RGBA. */
export async function readPng(file) {
  const png = PNG.sync.read(await readFile(file));
  return flattenOnWhite({ width: png.width, height: png.height, data: png.data });
}

/** Encodes an image as an RGB PNG. */
export function encodePng(img) {
  const png = new PNG({ width: img.width, height: img.height });
  png.data = Buffer.from(img.data.buffer, img.data.byteOffset, img.data.length);
  return PNG.sync.write(png, { colorType: 2, deflateLevel: 6 });
}

/**
 * Copies the rectangle out of an image.
 *
 * @throws {RangeError} when the rectangle is not inside the image
 */
export function cropImage(img, rect) {
  const { x, y, width, height } = rect;
  if (x < 0 || y < 0 || x + width > img.width || y + height > img.height) {
    throw new RangeError(`crop ${width} × ${height} at ${x}, ${y} lies outside the ${img.width} × ${img.height} image`);
  }
  const data = Buffer.alloc(width * height * 4);
  for (let row = 0; row < height; row += 1) {
    const from = ((y + row) * img.width + x) * 4;
    data.set(img.data.subarray(from, from + width * 4), row * width * 4);
  }
  return { width, height, data };
}

/** One byte per pixel: 1 where a mask covers it. */
export function maskBitmap(width, height, masks) {
  const bits = new Uint8Array(width * height);
  for (const m of masks) {
    for (let y = m.y; y < Math.min(height, m.y + m.height); y += 1) bits.fill(1, y * width + m.x, y * width + Math.min(width, m.x + m.width));
  }
  return bits;
}

/** Window starts from 0 in steps, plus one flush with the end so the last pixels are covered. */
function starts(length, window, step) {
  const out = [];
  for (let s = 0; s + window <= length; s += step) out.push(s);
  if (out.at(-1) !== length - window) out.push(length - window);
  return out;
}

/**
 * Mean structural similarity (SSIM, Wang et al. 2004) of the luma (Rec. 601) of two images of the
 * same size, over square windows (8 px, step 4, the last ones flush with the edges), with the
 * usual constants (K1 0.01, K2 0.03, L 255). Masked pixels are left out of every window, and a
 * window with nothing left is skipped. 1 means identical.
 *
 * @returns {number}
 */
export function meanSsim(a, b, mask, { window = 8, step = 4 } = {}) {
  const { width: w, height: h } = a;
  const luma = (img) => {
    const out = new Float64Array(w * h);
    for (let i = 0, p = 0; i < out.length; i += 1, p += 4) out[i] = 0.299 * img.data[p] + 0.587 * img.data[p + 1] + 0.114 * img.data[p + 2];
    return out;
  };
  const la = luma(a);
  const lb = luma(b);
  const c1 = (0.01 * 255) ** 2;
  const c2 = (0.03 * 255) ** 2;
  const win = Math.min(window, w, h);
  let sum = 0;
  let count = 0;
  for (const y0 of starts(h, win, step)) {
    for (const x0 of starts(w, win, step)) {
      let n = 0;
      let sa = 0;
      let sb = 0;
      let saa = 0;
      let sbb = 0;
      let sab = 0;
      for (let y = y0; y < y0 + win; y += 1) {
        for (let i = y * w + x0, end = i + win; i < end; i += 1) {
          if (mask && mask[i]) continue;
          const p = la[i];
          const q = lb[i];
          n += 1;
          sa += p;
          sb += q;
          saa += p * p;
          sbb += q * q;
          sab += p * q;
        }
      }
      if (n === 0) continue;
      const ma = sa / n;
      const mb = sb / n;
      const va = saa / n - ma * ma;
      const vb = sbb / n - mb * mb;
      const cov = sab / n - ma * mb;
      sum += ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma * ma + mb * mb + c1) * (va + vb + c2));
      count += 1;
    }
  }
  return count === 0 ? 1 : sum / count;
}

/**
 * Compares a reference with a golden of the same size.
 *
 * - `differing`: pixels whose YIQ colour distance exceeds the threshold, anti-aliased pixels left
 *   out (pixelmatch); `diffShare` is their share of the pixels no mask covers.
 * - `structDiff`: 1 − mean SSIM, so 0 means identical.
 * - `diff`: pixelmatch's image (the reference faded, red where pixels differ, yellow where the
 *   difference is anti-aliasing), with masked areas hatched.
 *
 * @param {{width: number, height: number, data: Buffer}} ref
 * @param {{width: number, height: number, data: Buffer}} golden
 * @param {{threshold?: number, masks?: Array<{x: number, y: number, width: number, height: number}>}} [options]
 */
export function compareImages(ref, golden, { threshold = DEFAULT_THRESHOLD, masks = [] } = {}) {
  if (!sameSize(ref, golden)) throw new RangeError(`sizes differ: reference ${size(ref)}, golden ${size(golden)}`);
  const { width, height } = ref;
  const mask = maskBitmap(width, height, masks);
  // Under a mask the golden takes the reference's pixels, so pixelmatch sees no difference there.
  const masked = { width, height, data: copyPixels(golden.data) };
  let maskedPixels = 0;
  for (let i = 0; i < mask.length; i += 1) {
    if (!mask[i]) continue;
    maskedPixels += 1;
    masked.data.set(ref.data.subarray(i * 4, i * 4 + 4), i * 4);
  }
  const diff = { width, height, data: Buffer.alloc(width * height * 4) };
  const differing = pixelmatch(ref.data, masked.data, diff.data, width, height, { threshold, includeAA: false, alpha: 0.1 });
  for (let i = 0; i < mask.length; i += 1) {
    if (!mask[i]) continue;
    const x = i % width;
    const y = (i - x) / width;
    const [r, g, b] = HATCH[((x + y) >> 3) & 1];
    diff.data[i * 4] = r;
    diff.data[i * 4 + 1] = g;
    diff.data[i * 4 + 2] = b;
    diff.data[i * 4 + 3] = 255;
  }
  const comparedPixels = width * height - maskedPixels;
  return {
    width,
    height,
    comparedPixels,
    differing,
    diffShare: comparedPixels === 0 ? 0 : differing / comparedPixels,
    structDiff: 1 - meanSsim(ref, golden, mask),
    diff,
  };
}

/** Draws a 2 px outline of the rectangle into an image, inside the rectangle's edges. */
function outline(img, rect, [r, g, b]) {
  const put = (x, y) => {
    if (x < 0 || y < 0 || x >= img.width || y >= img.height) return;
    const p = (y * img.width + x) * 4;
    img.data[p] = r;
    img.data[p + 1] = g;
    img.data[p + 2] = b;
    img.data[p + 3] = 255;
  };
  for (let t = 0; t < 2; t += 1) {
    for (let x = rect.x; x < rect.x + rect.width; x += 1) {
      put(x, rect.y + t);
      put(x, rect.y + rect.height - 1 - t);
    }
    for (let y = rect.y; y < rect.y + rect.height; y += 1) {
      put(rect.x + t, y);
      put(rect.x + rect.width - 1 - t, y);
    }
  }
}

/**
 * Reference | golden | diff, side by side with a grey gap; masked areas are outlined in magenta
 * on the reference and the golden.
 */
export function sideBySide(ref, golden, diff, masks = []) {
  const { width, height } = ref;
  const out = { width: width * 3 + GAP.width * 2, height, data: Buffer.alloc((width * 3 + GAP.width * 2) * height * 4) };
  for (let i = 0; i < out.width * height; i += 1) {
    out.data[i * 4] = GAP.colour[0];
    out.data[i * 4 + 1] = GAP.colour[1];
    out.data[i * 4 + 2] = GAP.colour[2];
    out.data[i * 4 + 3] = 255;
  }
  const panels = [ref, golden, diff].map((img) => ({ width, height, data: copyPixels(img.data) }));
  for (const m of masks) {
    outline(panels[0], m, MASK_OUTLINE);
    outline(panels[1], m, MASK_OUTLINE);
  }
  for (const [n, panel] of panels.entries()) {
    const left = n * (width + GAP.width);
    for (let y = 0; y < height; y += 1) out.data.set(panel.data.subarray(y * width * 4, (y + 1) * width * 4), (y * out.width + left) * 4);
  }
  return out;
}

// ---------------------------------------------------------------------------------------------
// A run

/**
 * Compares every pair of the map and writes `<id>.diff.png` and `<id>.side.png` into outDir for
 * each pair compared. A pair whose images are missing, unreadable or of the wrong size becomes a
 * row with that result; nothing here throws for one pair.
 *
 * @param {{goldenSize: object, pairs: Array<object>}} map from validateMap
 * @param {{refsDir: string, goldensDir: string, outDir: string, threshold?: number}} options
 * @returns {Promise<Array<{pair: object, result: string, detail?: string, scores?: object, images?: string[]}>>}
 */
export async function runComparison(map, { refsDir, goldensDir, outDir, threshold = DEFAULT_THRESHOLD }) {
  await mkdir(outDir, { recursive: true });
  const cache = new Map();
  const load = (file) => {
    if (!cache.has(file)) cache.set(file, readPng(file));
    return cache.get(file);
  };
  const rows = [];
  for (const pair of map.pairs) {
    const images = [`${pair.id}.side.png`, `${pair.id}.diff.png`];
    // An image from an earlier run must not look like this run's.
    for (const name of images) await rm(path.join(outDir, name), { force: true });
    if (pair.notCompared !== undefined) {
      rows.push({ pair, result: 'not compared' });
      continue;
    }
    const refFile = path.join(refsDir, `${pair.board}.png`);
    const goldenFile = path.join(goldensDir, pair.golden);
    const missing = [!existsSync(refFile) && 'reference', !existsSync(goldenFile) && 'golden'].filter(Boolean);
    if (missing.length > 0) {
      rows.push({ pair, result: 'missing', detail: `no ${missing.join(' and no ')}` });
      continue;
    }
    try {
      let ref = await load(refFile).catch((e) => Promise.reject(new Error(`reference ${pair.board}.png: ${e.message}`)));
      let golden = await load(goldenFile).catch((e) => Promise.reject(new Error(`golden: ${e.message}`)));
      if (!pair.goldenCrop && !sameSize(golden, map.goldenSize)) {
        throw new Error(`the golden is ${size(golden)}, not ${size(map.goldenSize)}`);
      }
      ref = pair.crop ? cropImage(ref, pair.crop) : ref;
      golden = pair.goldenCrop ? cropImage(golden, pair.goldenCrop) : golden;
      if (!sameSize(ref, golden)) throw new Error(`the reference${pair.crop ? "'s crop" : ''} is ${size(ref)}, the golden${pair.goldenCrop ? "'s crop" : ''} ${size(golden)}`);
      const scores = compareImages(ref, golden, { threshold, masks: pair.masks });
      await writeFile(path.join(outDir, images[1]), encodePng(scores.diff));
      await writeFile(path.join(outDir, images[0]), encodePng(sideBySide(ref, golden, scores.diff, pair.masks)));
      delete scores.diff;
      rows.push({ pair, result: 'compared', scores, images });
    } catch (error) {
      rows.push({ pair, result: 'error', detail: error instanceof Error ? error.message : String(error) });
    }
  }
  return rows;
}

// ---------------------------------------------------------------------------------------------
// The report

const cell = (text) => String(text).replace(/\r?\n/g, ' ').replace(/\|/g, '\\|');
const code = (text) => `\`${text}\``;
const percent = (share) => `${(share * 100).toFixed(2)} %`;
const rectText = (r) => `${r.width} × ${r.height} at ${r.x}, ${r.y}`;

/**
 * The report as Markdown: a summary line, how to read it, and one table row per pair.
 *
 * @param {Array<object>} rows from runComparison
 * @param {{threshold: number, refsLabel: string, goldensLabel: string, refsInfo?: string,
 *   goldenFiles?: string[] | null, runUrl?: string, pixelmatchVersion?: string}} context
 *   goldenFiles: the golden PNG names found, or null when the folder does not exist
 * @returns {string}
 */
export function renderReport(rows, context) {
  const count = (result) => rows.filter((r) => r.result === result).length;
  const compared = rows.filter((r) => r.result === 'compared');
  let summary = `**Summary:** ${rows.length} pairs: ${compared.length} compared, ${count('missing')} missing, ${count('error')} with errors, ${count('not compared')} not compared.`;
  if (compared.length > 0) {
    const shares = compared.map((r) => r.scores.diffShare).sort((a, b) => a - b);
    const mid = shares.length >> 1;
    const median = shares.length % 2 === 1 ? shares[mid] : (shares[mid - 1] + shares[mid]) / 2;
    const worst = compared.reduce((a, b) => (b.scores.diffShare > a.scores.diffShare ? b : a));
    summary += ` Differing pixels: median ${percent(median)}, highest ${percent(worst.scores.diffShare)} (${code(worst.pair.id)}).`;
  }

  const used = new Set(rows.map((r) => r.pair.golden).filter(Boolean));
  let goldensLine;
  if (context.goldenFiles == null) {
    goldensLine = `- Goldens: ${code(context.goldensLabel)} does not exist yet.`;
  } else {
    const matrix = context.goldenFiles.filter((f) => GOLDEN_NAME.test(f));
    const unpaired = matrix.filter((f) => !used.has(f)).length;
    goldensLine = `- Goldens: ${code(context.goldensLabel)}, ${matrix.length} of the golden matrix; ${unpaired} of them have no pair because no board draws that screen, theme, language or platform.`;
  }
  const artifact = context.runUrl ? ` They are in the \`design-compare\` artifact of [this run](${context.runUrl}).` : '';
  const pm = context.pixelmatchVersion ? `pixelmatch ${context.pixelmatchVersion}` : 'pixelmatch';

  const lines = [
    '# Golden-versus-reference comparison',
    '',
    'Informative: a person reviews these scores, and in M1 they are not a gate (ROADMAP §5 step 11).',
    '',
    summary,
    '',
    `- References: ${code(context.refsLabel)}${context.refsInfo ? ` (${context.refsInfo})` : ''}.`,
    goldensLine,
    `- Differing pixels: the share of the compared pixels (masks left out) whose colour differs by more than the YIQ threshold ${context.threshold}, anti-aliased pixels not counted (${pm}).`,
    '- 1 − SSIM: one minus the mean structural similarity of the luma over 8 × 8 windows. 0 is identical; it rises with differences in layout and texture rather than colour.',
    `- Images: ${code('<pair>.side.png')} is reference \\| golden \\| diff, with masked areas outlined in magenta; ${code('<pair>.diff.png')} is the diff alone: red differs, yellow is anti-aliasing (not counted), hatched is masked, the rest is the reference faded.${artifact}`,
    '',
    '| Pair | Board | Golden | Result | Differing pixels | 1 − SSIM | Images | Notes |',
    '|---|---|---|---|---:|---:|---|---|',
  ];
  for (const row of rows) {
    const { pair } = row;
    const notes = [];
    if (pair.notCompared) notes.push(pair.notCompared);
    if (pair.note) notes.push(pair.note);
    if (pair.crop) notes.push(`Board crop: ${rectText(pair.crop)}.`);
    if (pair.goldenCrop) notes.push(`Golden crop: ${rectText(pair.goldenCrop)}.`);
    if (pair.masks.length > 0) notes.push(`Masked: ${pair.masks.map((m) => `${m.label} ${rectText(m)}`).join('; ')}.`);
    const result = row.detail ? `${row.result}: ${row.detail}` : row.result;
    const s = row.scores;
    lines.push(
      `| ${[
        code(pair.id),
        code(pair.board),
        pair.golden ? code(pair.golden) : '–',
        result,
        s ? `${percent(s.diffShare)} (${s.differing.toLocaleString('en-US')} px)` : '–',
        s ? s.structDiff.toFixed(4) : '–',
        row.images ? row.images.map(code).join(', ') : '–',
        notes.join(' '),
      ]
        .map(cell)
        .join(' | ')} |`,
    );
  }
  lines.push('');
  return lines.join('\n');
}

// ---------------------------------------------------------------------------------------------
// The command

export const COMPARE_USAGE = `Usage: node tools/design-refs compare [options]

Lines up each golden with the render of its design board (the pairs in the map) and writes
<out>/report.md with two difference scores per pair, plus <pair>.diff.png and <pair>.side.png
(reference | golden | diff). The scores are informative and never fail the run.

Options:
  --refs <dir>       the board renders (default: build/design-refs)
  --goldens <dir>    the goldens (default: app/test/goldens/goldens/linux)
  --out <dir>        output directory (default: build/design-compare)
  --map <file>       the pairs (default: tools/design-refs/compare-map.json)
  --threshold <t>    pixelmatch's YIQ colour threshold, from 0 to 1 (default: ${DEFAULT_THRESHOLD})
  -h, --help         show this help

Exit codes: 0 when the report is written, whatever the scores and also with goldens missing;
64 for a usage error; 66 when the map or the reference folder cannot be read; 1 otherwise.`;

/**
 * Parses the options of `compare`.
 *
 * @param {string[]} argv the arguments after `compare`
 * @param {{refs: string, goldens: string, out: string, map: string}} defaults
 */
export function parseCompareCli(argv, defaults) {
  let parsed;
  try {
    parsed = parseArgs({
      args: argv,
      options: {
        refs: { type: 'string' },
        goldens: { type: 'string' },
        out: { type: 'string' },
        map: { type: 'string' },
        threshold: { type: 'string' },
        help: { type: 'boolean', short: 'h' },
      },
      strict: true,
      allowPositionals: false,
    });
  } catch (error) {
    throw new UsageError(error instanceof Error ? error.message : String(error));
  }
  const v = parsed.values;
  for (const key of ['refs', 'goldens', 'out', 'map']) if (v[key] === '') throw new UsageError(`--${key} needs a path`);
  const threshold = v.threshold === undefined ? DEFAULT_THRESHOLD : Number(v.threshold);
  if (v.threshold === '' || !Number.isFinite(threshold) || threshold < 0 || threshold > 1) throw new UsageError('--threshold takes a number from 0 to 1');
  return {
    refs: path.resolve(v.refs ?? defaults.refs),
    goldens: path.resolve(v.goldens ?? defaults.goldens),
    out: path.resolve(v.out ?? defaults.out),
    map: path.resolve(v.map ?? defaults.map),
    threshold,
    help: Boolean(v.help),
  };
}

/** A path relative to the repository when it lies inside it, for a report that reads the same anywhere. */
function label(p, repoDir) {
  const rel = path.relative(repoDir, p);
  return rel === '' ? '.' : rel.startsWith('..') || path.isAbsolute(rel) ? p : rel.split(path.sep).join('/');
}

async function readJson(file) {
  try {
    return JSON.parse(await readFile(file, 'utf8'));
  } catch {
    return undefined;
  }
}

/**
 * `node tools/design-refs compare`: returns the exit code and never throws.
 *
 * @param {string[]} argv the arguments after `compare`
 * @param {{repoDir: string, toolDir: string, log?: (line: string) => void, error?: (line: string) => void,
 *   env?: Record<string, string | undefined>}} context
 * @returns {Promise<number>}
 */
export async function compareMain(argv, { repoDir, toolDir, log = console.log, error = console.error, env = process.env }) {
  const defaults = {
    refs: path.join(repoDir, 'build', 'design-refs'),
    goldens: path.join(repoDir, 'app', 'test', 'goldens', 'goldens', 'linux'),
    out: path.join(repoDir, 'build', 'design-compare'),
    map: path.join(toolDir, 'compare-map.json'),
  };
  try {
    const options = parseCompareCli(argv, defaults);
    if (options.help) {
      log(COMPARE_USAGE);
      return EXIT.ok;
    }
    const designDir = path.join(repoDir, 'design');
    if (existsSync(designDir) && isInsideDir(options.out, designDir)) throw new UsageError('--out must not be inside design/');
    if (existsSync(options.goldens) && isInsideDir(options.out, options.goldens)) throw new UsageError('--out must not be inside the goldens folder');

    const list = await loadBoards(path.join(toolDir, 'boards.json'));
    const map = await loadMap(options.map, { boardIds: new Set([...list.boards, ...list.pages].map((b) => b.id)) });
    if (!existsSync(options.refs)) {
      throw new InputError(`no references in ${options.refs}: render them first (node tools/design-refs --only @m1)`);
    }
    const goldenFiles = existsSync(options.goldens) ? (await readdir(options.goldens)).filter((f) => f.endsWith('.png')).sort() : null;
    if (goldenFiles === null) error(`compare: ${options.goldens} does not exist; every pair is reported missing`);

    const rows = await runComparison(map, { refsDir: options.refs, goldensDir: options.goldens, outDir: options.out, threshold: options.threshold });
    const manifest = await readJson(path.join(options.refs, 'manifest.json'));
    const pm = await readJson(path.join(toolDir, 'node_modules', 'pixelmatch', 'package.json'));
    const runUrl =
      env.GITHUB_SERVER_URL && env.GITHUB_REPOSITORY && env.GITHUB_RUN_ID
        ? `${env.GITHUB_SERVER_URL}/${env.GITHUB_REPOSITORY}/actions/runs/${env.GITHUB_RUN_ID}`
        : undefined;
    const report = renderReport(rows, {
      threshold: options.threshold,
      refsLabel: label(options.refs, repoDir),
      goldensLabel: label(options.goldens, repoDir),
      refsInfo: manifest?.browser ? `${manifest.browser}, playwright-core ${manifest.playwrightCore}` : undefined,
      goldenFiles,
      runUrl,
      pixelmatchVersion: pm?.version,
    });
    const reportFile = path.join(options.out, 'report.md');
    await writeFile(reportFile, report);
    for (const row of rows) {
      const s = row.scores;
      const scores = s ? ` ${percent(s.diffShare)} differing, 1 − SSIM ${s.structDiff.toFixed(4)}` : '';
      log(`${row.pair.id.padEnd(10)} ${row.result}${row.detail ? ` (${row.detail})` : ''}${scores}`);
    }
    log(report.split('\n').find((l) => l.startsWith('**Summary:**'))?.replace(/\*\*|`/g, '') ?? '');
    log(`report: ${reportFile}`);
    return EXIT.ok;
  } catch (e) {
    const text = e instanceof Error ? e.message : String(e);
    if (e instanceof UsageError) {
      error(`design-refs compare: ${text}\n\n${COMPARE_USAGE}`);
      return EXIT.usage;
    }
    if (e instanceof InputError) {
      error(`design-refs compare: ${text}`);
      return EXIT.noInput;
    }
    error(`design-refs compare: ${text}`);
    return EXIT.failure;
  }
}
