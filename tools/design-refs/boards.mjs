// The board list: reads boards.json and checks it against the design export.
//
// The design files are the source of truth for which boards exist. boards.json records them so a
// render can be planned without parsing HTML, and every run checks that the two still agree.

import { readdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

/** Number of boards in the export: 9 fix boards in "00 Fixes" and 244 product boards. */
export const EXPECTED_BOARD_COUNT = 253;

/** Section files hold the boards: "00 Fixes.dc.html" to "15 Flows.dc.html". */
const SECTION_FILE = /^\d\d[a-z]? .+\.dc\.html$/;

/**
 * A board id as the section files write it: `id="f1"` or `id="a1-1"` on the board element, or
 * `bid="a4-1"` passed to the FmBoard component, which renders it as the element id.
 */
const BOARD_ID_ATTR = /\sb?id="([af]\d[^"]*)"/g;

/**
 * How a board is captured, by the `capture` field in boards.json.
 *
 * - `element`: the element with the id itself (fix boards f1 to f6a; f1 to f6 are sections).
 * - `fm-root`: the board frame, the first `.fm-root` inside the element with the id, or that
 *   element itself when it carries `.fm-root` (the seven sidebar boards a2-3p to a2-3x).
 * - `fm-roots`: every `.fm-root` inside the element with the id, clipped to the box around all of
 *   them (a2-3m draws six sidebars side by side).
 * - `page`: the first `.fm-root` of the page (the DS additions sheet, which has no board id).
 */
export const CAPTURE_MODES = ['element', 'fm-root', 'fm-roots', 'page'];

/**
 * Product boards that the default rule (`fm-root`) does not fit, with the mode they need:
 * a12-0 is a table of region formats with no `.fm-root` frame, and a2-3m draws six sidebar
 * frames side by side. Applied by scanDesign, so `--write-boards` reproduces them.
 */
export const CAPTURE_OVERRIDES = Object.freeze({ 'a12-0': 'element', 'a2-3m': 'fm-roots' });

/**
 * Returns the CSS selector whose first match is screenshotted for [board].
 *
 * @param {{id: string, capture: string}} board
 * @returns {string}
 */
export function selectorFor(board) {
  switch (board.capture) {
    case 'element':
      return `[id="${board.id}"]`;
    case 'fm-root':
      return `[id="${board.id}"].fm-root, [id="${board.id}"] .fm-root`;
    case 'fm-roots':
      return `[id="${board.id}"] .fm-root`;
    case 'page':
      return '#dc-root .fm-root';
    default:
      throw new Error(`board ${board.id}: unknown capture mode "${board.capture}"`);
  }
}

/**
 * The smallest box holding every box in [boxes], in the same `{x, y, width, height}` form.
 *
 * @param {Array<{x: number, y: number, width: number, height: number}>} boxes
 */
export function unionBox(boxes) {
  const left = Math.min(...boxes.map((b) => b.x));
  const top = Math.min(...boxes.map((b) => b.y));
  const right = Math.max(...boxes.map((b) => b.x + b.width));
  const bottom = Math.max(...boxes.map((b) => b.y + b.height));
  return { x: left, y: top, width: right - left, height: bottom - top };
}

/**
 * Scans the section files in [designDir] and returns every board in file order, then document
 * order: `{id, file, capture}`. Fix boards (`f…`) are captured as the element, product boards
 * (`a…`) by their `.fm-root` frame, except those in CAPTURE_OVERRIDES.
 *
 * @param {string} designDir
 * @returns {Promise<Array<{id: string, file: string, capture: string}>>}
 */
export async function scanDesign(designDir) {
  const files = (await readdir(designDir)).filter((f) => SECTION_FILE.test(f)).sort();
  const boards = [];
  for (const file of files) {
    const html = await readFile(path.join(designDir, file), 'utf8');
    for (const match of html.matchAll(BOARD_ID_ATTR)) {
      const id = match[1];
      const capture = CAPTURE_OVERRIDES[id] ?? (id.startsWith('f') ? 'element' : 'fm-root');
      boards.push({ id, file, capture });
    }
  }
  return boards;
}

/**
 * Reads and shape-checks boards.json.
 *
 * @param {string} file
 * @returns {Promise<{boards: Array<{id: string, file: string, capture: string}>,
 *   pages: Array<{id: string, file: string, capture: string}>, sets: Record<string, string[]>}>}
 */
export async function loadBoards(file) {
  const data = JSON.parse(await readFile(file, 'utf8'));
  for (const key of ['boards', 'pages']) {
    if (!Array.isArray(data[key])) throw new Error(`${file}: "${key}" must be an array`);
    for (const b of data[key]) {
      if (typeof b.id !== 'string' || typeof b.file !== 'string' || !CAPTURE_MODES.includes(b.capture)) {
        throw new Error(`${file}: bad entry in "${key}": ${JSON.stringify(b)}`);
      }
    }
  }
  if (typeof data.sets !== 'object' || data.sets === null) throw new Error(`${file}: "sets" must be an object`);
  return { boards: data.boards, pages: data.pages, sets: data.sets };
}

/**
 * Compares boards.json with a fresh scan of the design files and returns a list of problems
 * (empty when they agree).
 *
 * @param {{boards: Array<{id: string, file: string, capture: string}>,
 *   pages: Array<{id: string, file: string}>, sets: Record<string, string[]>}} list
 * @param {Array<{id: string, file: string, capture: string}>} scanned
 * @returns {string[]}
 */
export function validateBoards(list, scanned) {
  const problems = [];
  const seen = new Set();
  for (const b of [...list.boards, ...list.pages]) {
    if (seen.has(b.id)) problems.push(`duplicate id ${b.id}`);
    seen.add(b.id);
  }
  if (list.boards.length !== EXPECTED_BOARD_COUNT) {
    problems.push(`boards.json lists ${list.boards.length} boards, expected ${EXPECTED_BOARD_COUNT}`);
  }
  if (scanned.length !== EXPECTED_BOARD_COUNT) {
    problems.push(`the design files hold ${scanned.length} board ids, expected ${EXPECTED_BOARD_COUNT}`);
  }
  const listed = new Map(list.boards.map((b) => [b.id, b]));
  const found = new Map(scanned.map((b) => [b.id, b]));
  for (const b of scanned) {
    const l = listed.get(b.id);
    if (!l) problems.push(`${b.id} (${b.file}) is missing from boards.json`);
    else if (l.file !== b.file || l.capture !== b.capture) {
      problems.push(`${b.id}: boards.json says ${l.file} / ${l.capture}, design says ${b.file} / ${b.capture}`);
    }
  }
  for (const b of list.boards) {
    if (!found.has(b.id)) problems.push(`${b.id} is in boards.json but not in ${b.file}`);
  }
  for (const [name, ids] of Object.entries(list.sets)) {
    for (const id of ids) {
      if (!seen.has(id)) problems.push(`set ${name}: unknown id ${id}`);
    }
  }
  return problems;
}

/**
 * Writes boards.json with one entry per line, so a design re-export shows up as a readable diff.
 *
 * @param {string} file
 * @param {{boards: object[], pages: object[], sets: Record<string, string[]>}} list
 */
export async function writeBoards(file, list) {
  const entry = (b) => `    ${JSON.stringify({ id: b.id, file: b.file, capture: b.capture })}`;
  const sets = Object.entries(list.sets).map(([name, ids]) => `    ${JSON.stringify(name)}: ${JSON.stringify(ids)}`);
  const text = [
    '{',
    '  "$comment": "Every board of the design export, in file and document order. Checked against design/ on every run; regenerate with: node tools/design-refs --write-boards",',
    '  "boards": [',
    list.boards.map(entry).join(',\n'),
    '  ],',
    '  "pages": [',
    list.pages.map(entry).join(',\n'),
    '  ],',
    '  "sets": {',
    sets.join(',\n'),
    '  }',
    '}',
    '',
  ].join('\n');
  await writeFile(file, text);
}
