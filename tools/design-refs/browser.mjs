// The browser side of a render: which Chromium is launched, with which switches, and which
// uncaught page errors may be ignored.

import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

/** The executable inside a `chromium_headless_shell-<revision>` folder (playwright-core 1.56.1 layout). */
const SHELL_EXECUTABLE = {
  linux: ['chrome-linux', 'headless_shell'],
  darwin: ['chrome-mac', 'headless_shell'],
  win32: ['chrome-win', 'headless_shell.exe'],
};

/** Where the development container keeps its preinstalled browsers. */
export const CONTAINER_BROWSERS = '/opt/pw-browsers';

/**
 * Chromium switches for every launch.
 *
 * - A proxy on a closed local port: a request that escaped the routing in routes.mjs would go
 *   there, not out. Raw switches, because Playwright's proxy option also sends loopback through it.
 * - Unhinted, greyscale-antialiased text, so a plain headless shell (CI) rasterises glyphs like
 *   the development container's, whose launcher script already passes these two switches.
 *   Playwright itself adds --force-color-profile=srgb.
 */
export const LAUNCH_ARGS = [
  '--proxy-server=http://127.0.0.1:9',
  '--proxy-bypass-list=127.0.0.1',
  '--font-render-hinting=none',
  '--disable-lcd-text',
];

/**
 * The revision and version of the Chromium headless shell the installed playwright-core drives.
 *
 * @param {string} modulesDir
 * @returns {{revision: string, version: string}}
 */
export function expectedShell(modulesDir) {
  const { browsers } = JSON.parse(readFileSync(path.join(modulesDir, 'playwright-core', 'browsers.json'), 'utf8'));
  const shell = browsers.find((b) => b.name === 'chromium-headless-shell');
  if (!shell) throw new Error('playwright-core/browsers.json names no chromium-headless-shell');
  return { revision: shell.revision, version: shell.browserVersion };
}

/**
 * Picks the Chromium executable. The first that applies wins:
 *
 * 1. `--chromium <path>`;
 * 2. the environment variable `FERMAN_CHROMIUM`;
 * 3. `$PLAYWRIGHT_BROWSERS_PATH/chromium_headless_shell-<revision>/…`, if it exists;
 * 4. `/opt/pw-browsers/chromium_headless_shell-<revision>/…`, if it exists;
 * 5. no executable path: Playwright looks in its own default browser folder.
 *
 * An explicit path (1 or 2) that does not exist is an error, never skipped.
 *
 * @param {{cli?: string, env?: Record<string, string | undefined>, revision: string,
 *   platform?: string, exists?: (p: string) => boolean}} options
 * @returns {{executablePath: string | undefined, source: string, tried: string[]}}
 */
export function resolveChromium({ cli, env = process.env, revision, platform = process.platform, exists = existsSync }) {
  for (const [value, source] of [
    [cli, '--chromium'],
    [env.FERMAN_CHROMIUM, 'FERMAN_CHROMIUM'],
  ]) {
    if (value === undefined || value === '') continue;
    const executablePath = path.resolve(value);
    if (!exists(executablePath)) throw new Error(`${source}: there is no Chromium executable at ${executablePath}`);
    return { executablePath, source, tried: [] };
  }
  const tried = [];
  const relative = SHELL_EXECUTABLE[platform];
  if (relative) {
    for (const [base, source] of [
      [env.PLAYWRIGHT_BROWSERS_PATH, 'PLAYWRIGHT_BROWSERS_PATH'],
      [CONTAINER_BROWSERS, CONTAINER_BROWSERS],
    ]) {
      if (!base) continue;
      const executablePath = path.join(base, `chromium_headless_shell-${revision}`, ...relative);
      if (exists(executablePath)) return { executablePath, source, tried };
      tried.push(executablePath);
    }
  }
  return { executablePath: undefined, source: "Playwright's default browser folder", tried };
}

/**
 * Uncaught page errors that do not fail a board. Every entry names the boards it applies to
 * (`'*'` for all), a pattern for the error message and the reason the board is still complete:
 *
 *     { boards: ['a3-15'], match: /ResizeObserver loop/, reason: 'benign: …' }
 *
 * Empty: no board throws today.
 *
 * @type {ReadonlyArray<{boards: string[], match: RegExp, reason: string}>}
 */
export const ALLOWED_PAGE_ERRORS = [];

/**
 * The page errors of [boardId] that no allow-list entry covers.
 *
 * @param {string} boardId
 * @param {string[]} errors
 * @param {ReadonlyArray<{boards: string[], match: RegExp, reason: string}>} [allowed]
 * @returns {string[]}
 */
export function unexpectedPageErrors(boardId, errors, allowed = ALLOWED_PAGE_ERRORS) {
  for (const entry of allowed) {
    if (typeof entry.reason !== 'string' || entry.reason.trim() === '') {
      throw new Error(`allowed page error ${String(entry.match)} has no reason`);
    }
  }
  const applies = (entry) => entry.boards.includes('*') || entry.boards.includes(boardId);
  return errors.filter((error) => !allowed.some((entry) => applies(entry) && error.search(entry.match) !== -1));
}
