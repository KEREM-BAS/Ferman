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
 * The languages a board with the design's board-language switch is also rendered in. The switch
 * offers EN, TR and AR; English is the default and the board's plain render (`<id>.png`), each
 * other language a variant (`<id>.<lang>.png`).
 */
export const BOARD_LANGS = Object.freeze(['tr', 'ar']);

/** The localStorage key the design's board-language switch reads when a section page loads. */
export const LANG_KEY = 'fm-gap-lang';

/** A board's markup binds `setGl` when it carries the board-language switch. */
const LANG_SWITCH = /\{\{\s*setGl\s*\}\}/;

/**
 * Returns the CSS selector whose first match is screenshotted for [board].
 *
 * @param {{id: string, capture: string}} board
 * @returns {string}
 */
export function selectorFor(board) {
  const id = domId(board);
  switch (board.capture) {
    case 'element':
      return `[id="${id}"]`;
    case 'fm-root':
      return `[id="${id}"].fm-root, [id="${id}"] .fm-root`;
    case 'fm-roots':
      return `[id="${id}"] .fm-root`;
    case 'page':
      return '#dc-root .fm-root';
    default:
      throw new Error(`board ${board.id}: unknown capture mode "${board.capture}"`);
  }
}

/**
 * The id of the board's element in the design page: the board id, also for a language variant
 * (`a1-9c.tr` is the element `a1-9c`).
 *
 * @param {{id: string, board?: string}} target
 */
export function domId(target) {
  return target.board ?? target.id;
}

/**
 * The render targets of [boards]: each board itself, then one variant per language in its
 * `langs`, `{...board, id: '<id>.<lang>', board: '<id>', lang}`. Every target renders on its own
 * page to `<target id>.png`.
 *
 * @param {Array<{id: string, file: string, capture: string, langs?: string[]}>} boards
 */
export function expandTargets(boards) {
  return boards.flatMap((b) => [
    { ...b, board: b.id },
    ...(b.langs ?? []).map((lang) => ({ ...b, id: `${b.id}.${lang}`, board: b.id, lang })),
  ]);
}

/**
 * The language a target's board must show once rendered: its variant language, English for the
 * plain render of a board with a language switch, and null for a board without one.
 *
 * @param {{lang?: string, langs?: string[]}} target
 * @returns {string | null}
 */
export function expectedLang(target) {
  return target.lang ?? (target.langs ? 'en' : null);
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
 * order: `{id, file, capture}`, plus `langs` (BOARD_LANGS) for a board whose markup, from its id
 * to the next board's, carries the board-language switch. Fix boards (`f…`) are captured as the
 * element, product boards (`a…`) by their `.fm-root` frame, except those in CAPTURE_OVERRIDES.
 *
 * @param {string} designDir
 * @returns {Promise<Array<{id: string, file: string, capture: string, langs?: string[]}>>}
 */
export async function scanDesign(designDir) {
  const files = (await readdir(designDir)).filter((f) => SECTION_FILE.test(f)).sort();
  const boards = [];
  for (const file of files) {
    const html = await readFile(path.join(designDir, file), 'utf8');
    const matches = [...html.matchAll(BOARD_ID_ATTR)];
    for (const [i, match] of matches.entries()) {
      const id = match[1];
      const capture = CAPTURE_OVERRIDES[id] ?? (id.startsWith('f') ? 'element' : 'fm-root');
      const markup = html.slice(match.index, matches[i + 1]?.index ?? html.length);
      boards.push(LANG_SWITCH.test(markup) ? { id, file, capture, langs: [...BOARD_LANGS] } : { id, file, capture });
    }
  }
  return boards;
}

/**
 * Reads and shape-checks boards.json.
 *
 * @param {string} file
 * @returns {Promise<{boards: Array<{id: string, file: string, capture: string, langs?: string[]}>,
 *   pages: Array<{id: string, file: string, capture: string}>, sets: Record<string, string[]>}>}
 */
export async function loadBoards(file) {
  const data = JSON.parse(await readFile(file, 'utf8'));
  const goodLangs = (langs) =>
    langs === undefined ||
    (Array.isArray(langs) && langs.length > 0 && new Set(langs).size === langs.length && langs.every((l) => BOARD_LANGS.includes(l)));
  for (const key of ['boards', 'pages']) {
    if (!Array.isArray(data[key])) throw new Error(`${file}: "${key}" must be an array`);
    for (const b of data[key]) {
      if (typeof b.id !== 'string' || typeof b.file !== 'string' || !CAPTURE_MODES.includes(b.capture) || !goodLangs(b.langs)) {
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
 * @param {{boards: Array<{id: string, file: string, capture: string, langs?: string[]}>,
 *   pages: Array<{id: string, file: string}>, sets: Record<string, string[]>}} list
 * @param {Array<{id: string, file: string, capture: string, langs?: string[]}>} scanned
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
  const langsOf = (b) => (b.langs ?? []).join(',') || 'none';
  for (const b of scanned) {
    const l = listed.get(b.id);
    if (!l) problems.push(`${b.id} (${b.file}) is missing from boards.json`);
    else if (l.file !== b.file || l.capture !== b.capture || langsOf(l) !== langsOf(b)) {
      problems.push(
        `${b.id}: boards.json says ${l.file} / ${l.capture} / langs ${langsOf(l)}, ` +
          `design says ${b.file} / ${b.capture} / langs ${langsOf(b)}`,
      );
    }
  }
  for (const b of list.boards) {
    if (!found.has(b.id)) problems.push(`${b.id} is in boards.json but not in ${b.file}`);
  }
  const targets = new Set(expandTargets([...list.boards, ...list.pages]).map((t) => t.id));
  for (const [name, ids] of Object.entries(list.sets)) {
    for (const id of ids) {
      if (!targets.has(id)) problems.push(`set ${name}: unknown id ${id}`);
    }
  }
  const switchable = langsSet(scanned);
  if ((list.sets.langs ?? []).join(' ') !== switchable.join(' ')) {
    problems.push(`set langs must list the ${switchable.length} boards with a language switch, in board order`);
  }
  return problems;
}

/**
 * The `langs` set: every board with the board-language switch, in board order. `--write-boards`
 * writes it and every run checks it, so `--only @langs` renders exactly those boards.
 *
 * @param {Array<{id: string, langs?: string[]}>} boards
 */
export function langsSet(boards) {
  return boards.filter((b) => b.langs).map((b) => b.id);
}

/**
 * Writes boards.json with one entry per line, so a design re-export shows up as a readable diff.
 *
 * @param {string} file
 * @param {{boards: object[], pages: object[], sets: Record<string, string[]>}} list
 */
export async function writeBoards(file, list) {
  const entry = (b) =>
    `    ${JSON.stringify(b.langs ? { id: b.id, file: b.file, capture: b.capture, langs: b.langs } : { id: b.id, file: b.file, capture: b.capture })}`;
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
