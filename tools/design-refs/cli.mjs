// Command-line handling: options, board selection and the guard that keeps output out of design/.
// Kept apart from index.mjs, which starts rendering when it is loaded, so it can be unit-tested.

import { realpathSync, statSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { parseArgs } from 'node:util';

export class UsageError extends Error {}

export function defaultJobs() {
  return Math.max(1, Math.min(4, os.availableParallelism()));
}

export const USAGE = `Usage: node tools/design-refs [options]

Renders design boards to <out>/<id>.png, offline.

Options:
  --only <ids>       render only these ids (comma-separated, repeatable); @<set> expands a set
                     from boards.json (@m1), ds-additions is the DS additions sheet
  --out <dir>        output directory (default: build/design-refs in the repository)
  --twice            render a second time in a fresh browser and fail unless every PNG is identical
  --jobs <n>         boards rendered in parallel (default: ${defaultJobs()})
  --chromium <path>  the Chromium executable to launch (default: $FERMAN_CHROMIUM, then
                     chromium_headless_shell-<revision> in $PLAYWRIGHT_BROWSERS_PATH, then in
                     /opt/pw-browsers, then Playwright's default browser folder)
  --list             print the boards and sets, then exit
  --write-boards     regenerate boards.json from the design files, then exit
  -h, --help         show this help

Needs the Chromium headless shell of playwright-core 1.56.1 (revision 1194). On Linux x64,
tools/design-refs/fetch-chromium.sh downloads it and prints the path to pass to --chromium.`;

/**
 * Parses the command line.
 *
 * @param {string[]} argv the arguments after the script name
 * @param {{defaultOut: string}} defaults
 */
export function parseCli(argv, { defaultOut }) {
  let parsed;
  try {
    parsed = parseArgs({
      args: argv,
      options: {
        only: { type: 'string', multiple: true },
        out: { type: 'string' },
        twice: { type: 'boolean' },
        jobs: { type: 'string' },
        chromium: { type: 'string' },
        list: { type: 'boolean' },
        'write-boards': { type: 'boolean' },
        help: { type: 'boolean', short: 'h' },
      },
      strict: true,
      allowPositionals: false,
    });
  } catch (error) {
    throw new UsageError(error instanceof Error ? error.message : String(error));
  }
  const v = parsed.values;
  const jobs = v.jobs === undefined ? defaultJobs() : Number(v.jobs);
  if (!Number.isInteger(jobs) || jobs < 1 || jobs > 16) throw new UsageError('--jobs takes a whole number from 1 to 16');
  if (v.chromium === '') throw new UsageError('--chromium needs a path');
  return {
    only: (v.only ?? []).flatMap((s) => s.split(/[\s,]+/)).filter(Boolean),
    out: path.resolve(v.out ?? defaultOut),
    twice: Boolean(v.twice),
    jobs,
    chromium: v.chromium === undefined ? undefined : path.resolve(v.chromium),
    list: Boolean(v.list),
    writeBoards: Boolean(v['write-boards']),
    help: Boolean(v.help),
  };
}

/**
 * Resolves --only into board entries, in the order of boards.json.
 *
 * @param {{boards: Array<{id: string}>, pages: Array<{id: string}>, sets: Record<string, string[]>}} list
 * @param {string[]} only
 */
export function selectTargets(list, only) {
  const all = [...list.boards, ...list.pages];
  if (only.length === 0) return all;
  const wanted = new Set();
  const unknown = [];
  for (const token of only) {
    if (token.startsWith('@')) {
      const set = list.sets[token.slice(1)];
      if (set) set.forEach((id) => wanted.add(id));
      else unknown.push(token);
    } else if (all.some((b) => b.id === token)) {
      wanted.add(token);
    } else {
      unknown.push(token);
    }
  }
  if (unknown.length > 0) throw new UsageError(`unknown board id or set: ${unknown.join(', ')} (see --list)`);
  return all.filter((b) => wanted.has(b.id));
}

/**
 * The real path of [p] with every symlink resolved, also when [p] does not exist yet: the real
 * path of its nearest existing ancestor, joined with the part that does not exist.
 *
 * @param {string} p
 * @returns {string}
 */
export function realpathOfNearest(p) {
  let current = path.resolve(p);
  const tail = [];
  for (;;) {
    try {
      return path.join(realpathSync.native(current), ...tail);
    } catch (error) {
      const code = /** @type {NodeJS.ErrnoException} */ (error).code;
      const parent = path.dirname(current);
      if ((code !== 'ENOENT' && code !== 'ENOTDIR') || parent === current) throw error;
      tail.unshift(path.basename(current));
      current = parent;
    }
  }
}

/**
 * Whether the filesystem matches names case-insensitively in the folder holding [dir] (the
 * default on macOS and Windows): the name with its case swapped finds the same directory.
 *
 * @param {string} dir an existing directory, as a real path
 * @returns {boolean}
 */
export function isCaseInsensitiveDir(dir) {
  const name = path.basename(dir);
  const swapped = [...name].map((c) => (c === c.toLowerCase() ? c.toUpperCase() : c.toLowerCase())).join('');
  if (swapped === name) return process.platform === 'darwin' || process.platform === 'win32';
  try {
    const a = statSync(dir, { bigint: true });
    const b = statSync(path.join(path.dirname(dir), swapped), { bigint: true });
    return a.dev === b.dev && a.ino === b.ino;
  } catch {
    return false;
  }
}

/**
 * Whether [dir] is [root] or lies inside it once symlinks are resolved (for a [dir] that does not
 * exist yet, those of its nearest existing ancestor), comparing names case-insensitively where
 * the filesystem holding [root] does.
 *
 * @param {string} dir
 * @param {string} root an existing directory
 * @param {{caseInsensitive?: boolean}} [options] caseInsensitive: override the detection (tests)
 * @returns {boolean}
 */
export function isInsideDir(dir, root, { caseInsensitive } = {}) {
  const realRoot = realpathSync.native(root);
  const realDir = realpathOfNearest(dir);
  const insensitive = caseInsensitive ?? isCaseInsensitiveDir(realRoot);
  const fold = (p) => (insensitive ? p.normalize('NFC').toLowerCase() : p);
  const rel = path.relative(fold(realRoot), fold(realDir));
  return rel === '' || (rel !== '..' && !rel.startsWith(`..${path.sep}`) && !path.isAbsolute(rel));
}
