#!/usr/bin/env node
// tools/design-refs: renders every board of the read-only design export to one PNG per board id,
// offline, as the visual reference for the app's goldens; `compare` lines the goldens up with those
// references (compare.mjs). See README.md.

import { createHash } from 'node:crypto';
import { existsSync } from 'node:fs';
import { copyFile, mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import pixelmatch from 'pixelmatch';
import { chromium } from 'playwright-core';
import { PNG } from 'pngjs';

import { loadBoards, scanDesign, selectorFor, validateBoards, writeBoards } from './boards.mjs';
import { LAUNCH_ARGS, expectedShell, resolveChromium, unexpectedPageErrors } from './browser.mjs';
import { USAGE, UsageError, isInsideDir, parseCli, selectTargets } from './cli.mjs';
import { compareMain } from './compare.mjs';
import { countCheck, runStatus } from './outcome.mjs';
import { createOfflineRouter } from './routes.mjs';
import { startServer } from './server.mjs';

const TOOL_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_DIR = path.resolve(TOOL_DIR, '..', '..');
const DESIGN_DIR = path.join(REPO_DIR, 'design');
const MODULES_DIR = path.join(TOOL_DIR, 'node_modules');
const BOARDS_FILE = path.join(TOOL_DIR, 'boards.json');
const DEFAULT_OUT = path.join(REPO_DIR, 'build', 'design-refs');

/** Holds a 1440 × 900 desktop board with its caption; larger boards are captured beyond it. */
const VIEWPORT = { width: 1920, height: 1200 };
const TIMEOUT_MS = 90_000;

/**
 * Stops every CSS animation and transition for good, which shows each element in its resting
 * style: the text caret visible, spinners and progress bars at their start, dialogs fully faded
 * in (the states Playwright's `animations: 'disabled'` gives for a single screenshot). A running
 * animation can keep an element on its own compositor layer, which changes antialiasing nearby.
 */
const STILL_CSS = `*, *::before, *::after {
  animation: none !important;
  transition: none !important;
}`;

async function runPool(items, jobs, worker) {
  let next = 0;
  const lanes = Array.from({ length: Math.min(jobs, items.length) }, async () => {
    while (next < items.length) {
      const item = items[next];
      next += 1;
      await worker(item);
    }
  });
  await Promise.all(lanes);
}

const sha256 = (buffer) => createHash('sha256').update(buffer).digest('hex');
const seconds = (ms) => `${(ms / 1000).toFixed(1)} s`;
const message = (error) => (error instanceof Error ? error.message.split('\n')[0] : String(error));

/**
 * Waits until the design runtime has rendered the page completely: every component resolved
 * (no `.sc-placeholder` left), no requests in flight, all fonts loaded and the DOM unchanged over
 * consecutive frames; then lays the page out afresh.
 */
async function waitForPage(page) {
  await page
    .waitForFunction(
      () => {
        const root = document.getElementById('dc-root');
        return root !== null && root.childElementCount > 0 && document.querySelector('.sc-placeholder') === null;
      },
      null,
      { timeout: TIMEOUT_MS, polling: 100 },
    )
    .catch(() => {
      throw new Error(`components were still loading after ${seconds(TIMEOUT_MS)}`);
    });
  await page.waitForLoadState('networkidle', { timeout: TIMEOUT_MS });
  await page.evaluate(async () => {
    const frame = () => new Promise((resolve) => requestAnimationFrame(() => resolve(undefined)));
    const pause = () => new Promise((resolve) => setTimeout(resolve, 100));
    let previous = '';
    for (let i = 0; i < 100; i += 1) {
      await frame();
      await frame();
      await document.fonts.ready;
      const root = document.getElementById('dc-root');
      const signature = `${document.getElementsByTagName('*').length}:${root ? root.innerHTML.length : -1}`;
      if (signature === previous && document.fonts.status === 'loaded') return;
      previous = signature;
      await pause();
    }
    throw new Error('the page kept changing for 20 s');
  });
  // Lay the whole page out once more now that every font is loaded. Chromium does not always
  // redo layout that depends on a web font that arrives late (seen with text-combine-upright in
  // the vertical Japanese text of a3-15), so the pixels would depend on the font loading order.
  await page.evaluate(async () => {
    const root = document.documentElement;
    root.style.setProperty('display', 'none');
    void root.offsetHeight;
    root.style.removeProperty('display');
    void root.offsetHeight;
    await document.fonts.ready;
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve(undefined))));
  });
}

/** Screenshots one board and returns its PNG. Throws when the board is missing or incomplete. */
async function captureBoard(page, board) {
  if (board.capture !== 'page') {
    const ids = await page.locator(`[id="${board.id}"]`).count();
    if (ids !== 1) throw new Error(`${ids} elements have id "${board.id}"; expected 1`);
  }
  const target = page.locator(selectorFor(board)).first();
  if ((await target.count()) === 0) throw new Error(`nothing matches ${selectorFor(board)}`);
  const problems = await target.evaluate((el) => {
    const checks = [
      ['.sc-placeholder', 'unresolved component placeholder'],
      ['.sc-placeholder-error', 'component load error'],
      ['.sc-logic-error', 'component logic error'],
      ['.sc-interp.sc-missing, .sc-interp.sc-unresolved', 'unresolved template value'],
    ];
    return checks
      .map(([selector, label]) => [el.querySelectorAll(selector).length, label])
      .filter(([n]) => n > 0)
      .map(([n, label]) => `${n} × ${label}`);
  });
  if (problems.length > 0) throw new Error(problems.join(', '));
  // Clip to the element's box in document coordinates, rounded the way Chromium snaps boxes to
  // pixels, so a 1440 × 900 frame at a fractional offset gives a 1440 × 900 PNG (an element
  // screenshot would round outwards and add a row of the page around it).
  const box = await target.evaluate((el) => {
    const r = el.getBoundingClientRect();
    return { x: r.left + window.scrollX, y: r.top + window.scrollY, width: r.width, height: r.height };
  });
  const x = Math.round(box.x);
  const y = Math.round(box.y);
  const clip = { x, y, width: Math.round(box.x + box.width) - x, height: Math.round(box.y + box.height) - y };
  if (clip.width <= 0 || clip.height <= 0) throw new Error(`empty box ${JSON.stringify(box)}`);
  return page.screenshot({ type: 'png', fullPage: true, clip, animations: 'disabled', caret: 'hide', scale: 'css', timeout: TIMEOUT_MS });
}

/**
 * Renders one board on a freshly loaded page and writes `<id>.png` into outDir.
 *
 * Every board gets its own page, and its screenshot is the first one taken there. Repeated
 * full-page screenshots on one page do not always give the same pixels (a3-15 flips between two
 * antialiasing results), and screenshots after scrolling depend on what was drawn before, so a
 * shared page would make a board's PNG depend on which boards were rendered before it.
 *
 * The board fails, and leaves no PNG, when its page throws an uncaught error that
 * ALLOWED_PAGE_ERRORS does not cover, a request is blocked, or a file is missing from design/.
 */
async function renderBoard(browser, router, origin, board, outDir) {
  const file = path.join(outDir, `${board.id}.png`);
  // A board that fails must not leave the PNG of an earlier run behind as if it were current.
  await rm(file, { force: true });
  const problems = [];
  const pageErrors = [];
  let png;
  const context = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: 1,
    reducedMotion: 'reduce',
    colorScheme: 'light',
    forcedColors: 'none',
    locale: 'en-US',
    timezoneId: 'UTC',
    serviceWorkers: 'block',
  });
  try {
    await router.install(context, (v) => problems.push(`blocked request ${v.url} (${v.reason})`));
    const page = await context.newPage();
    page.on('pageerror', (error) => pageErrors.push(message(error)));
    page.on('response', (response) => {
      const url = new URL(response.url());
      if (response.status() === 404 && url.origin === origin && url.pathname !== '/favicon.ico') {
        problems.push(`not found in design/: ${url.pathname}`);
      }
    });
    await page.goto(`${origin}/${encodeURIComponent(board.file)}`, { waitUntil: 'load', timeout: TIMEOUT_MS });
    await page.addStyleTag({ content: STILL_CSS });
    await waitForPage(page);
    png = await captureBoard(page, board);
  } catch (error) {
    problems.unshift(message(error));
  } finally {
    await context.close();
  }
  problems.push(...unexpectedPageErrors(board.id, pageErrors).map((e) => `uncaught page error: ${e}`));
  if (problems.length > 0 || png === undefined) throw new Error([...new Set(problems)].join('; ') || 'no screenshot');
  await writeFile(file, png);
  return { ...board, width: png.readUInt32BE(16), height: png.readUInt32BE(20), sha256: sha256(png) };
}

/** One render of the targets in a freshly launched browser. */
async function renderPass(targets, outDir, { router, origin, jobs, label, log, executablePath }) {
  await mkdir(outDir, { recursive: true });
  let browser;
  try {
    browser = await chromium.launch({ headless: true, executablePath, args: LAUNCH_ARGS });
  } catch (error) {
    const which = executablePath ?? "from Playwright's default browser folder";
    throw new Error(
      `cannot launch Chromium ${which} (${message(error)}). Pass the headless shell with ` +
        '--chromium <path> or FERMAN_CHROMIUM; on Linux x64, tools/design-refs/fetch-chromium.sh ' +
        'downloads it and prints the path.',
    );
  }
  const browserVersion = browser.version();
  const results = new Map();
  const failures = [];
  const started = performance.now();
  const width = String(targets.length).length;
  let finished = 0;
  try {
    await runPool(targets, jobs, async (board) => {
      const t0 = performance.now();
      let line;
      try {
        const r = await renderBoard(browser, router, origin, board, outDir);
        results.set(board.id, r);
        line = `${board.id} ${r.width}×${r.height}`;
      } catch (error) {
        failures.push({ id: board.id, file: board.file, reason: message(error) });
        line = `${board.id} FAILED`;
      }
      finished += 1;
      log(`${label}[${String(finished).padStart(width)}/${targets.length}] ${line} (${board.file}) ${seconds(performance.now() - t0)}`);
    });
  } finally {
    await browser.close();
  }
  return { results, failures, ms: performance.now() - started, browserVersion };
}

/**
 * Compares two renders of the same boards. For every board that differs, both renders move to
 * diffDir as `<id>.first.png` and `<id>.second.png`, next to a pixel diff `<id>.diff.png`.
 *
 * @returns {Promise<Array<{id: string, reason: string}>>}
 */
async function comparePasses(first, second, firstDir, secondDir, diffDir) {
  const mismatches = [];
  for (const [id, a] of first) {
    const b = second.get(id);
    if (!b || a.sha256 === b.sha256) continue; // a board missing from the second render failed there
    const fileA = path.join(firstDir, `${id}.png`);
    const fileB = path.join(secondDir, `${id}.png`);
    const imgA = PNG.sync.read(await readFile(fileA));
    const imgB = PNG.sync.read(await readFile(fileB));
    await mkdir(diffDir, { recursive: true });
    await rename(fileA, path.join(diffDir, `${id}.first.png`));
    await copyFile(fileB, path.join(diffDir, `${id}.second.png`));
    if (imgA.width !== imgB.width || imgA.height !== imgB.height) {
      mismatches.push({ id, reason: `size ${imgA.width}×${imgA.height} vs ${imgB.width}×${imgB.height}` });
      continue;
    }
    const diff = new PNG({ width: imgA.width, height: imgA.height });
    const pixels = pixelmatch(imgA.data, imgB.data, diff.data, imgA.width, imgA.height, { threshold: 0 });
    await writeFile(path.join(diffDir, `${id}.diff.png`), PNG.sync.write(diff));
    mismatches.push({ id, reason: `${pixels} pixel(s) differ, see ${path.join(diffDir, `${id}.*.png`)}` });
  }
  return mismatches;
}

/**
 * Writes <out>/manifest.json: size and SHA-256 of every PNG, for comparisons. Entries for boards
 * not rendered this time are kept from the previous manifest while their PNG still exists, so a
 * --only run updates the manifest of a full run instead of replacing it. A board that failed
 * this time has no PNG any more, so its entry goes.
 */
async function writeManifest(outDir, allBoards, pass) {
  const file = path.join(outDir, 'manifest.json');
  const entries = new Map();
  try {
    for (const entry of JSON.parse(await readFile(file, 'utf8')).boards ?? []) entries.set(entry.id, entry);
  } catch {
    // No previous manifest, or an unreadable one: start afresh.
  }
  for (const { id, file: source, capture, width, height, sha256: hash } of pass.results.values()) {
    entries.set(id, { id, file: source, capture, width, height, sha256: hash });
  }
  const boards = allBoards
    .filter((b) => entries.has(b.id) && (pass.results.has(b.id) || existsSync(path.join(outDir, `${b.id}.png`))))
    .map((b) => entries.get(b.id));
  const manifest = {
    tool: 'tools/design-refs',
    playwrightCore: JSON.parse(await readFile(path.join(MODULES_DIR, 'playwright-core', 'package.json'), 'utf8')).version,
    browser: `chromium ${pass.browserVersion}`,
    viewport: VIEWPORT,
    deviceScaleFactor: 1,
    boards,
  };
  await writeFile(file, `${JSON.stringify(manifest, null, 2)}\n`);
}

async function main() {
  const options = parseCli(process.argv.slice(2), { defaultOut: DEFAULT_OUT });
  if (options.help) {
    console.log(USAGE);
    return 0;
  }
  const log = (line) => console.log(line);

  const scanned = await scanDesign(DESIGN_DIR);
  if (options.writeBoards) {
    const current = await loadBoards(BOARDS_FILE);
    await writeBoards(BOARDS_FILE, { ...current, boards: scanned });
    log(`boards.json: ${scanned.length} boards from ${new Set(scanned.map((b) => b.file)).size} design files`);
    return 0;
  }
  const list = await loadBoards(BOARDS_FILE);
  const problems = validateBoards(list, scanned);
  if (problems.length > 0) {
    for (const p of problems) console.error(`boards.json: ${p}`);
    console.error('boards.json does not match design/. Regenerate it with: node tools/design-refs --write-boards');
    return 1;
  }
  if (options.list) {
    for (const b of [...list.boards, ...list.pages]) log(`${b.id.padEnd(14)}${b.capture.padEnd(9)}${b.file}`);
    for (const [name, ids] of Object.entries(list.sets)) log(`@${name}: ${ids.join(' ')}`);
    log(`${list.boards.length} boards, ${list.pages.length} page(s)`);
    return 0;
  }

  // Symlinks resolved, and case-insensitive where the filesystem is: nothing may land in design/.
  if (isInsideDir(options.out, DESIGN_DIR)) throw new UsageError('--out must not be inside design/');
  const targets = selectTargets(list, options.only);
  const shell = expectedShell(MODULES_DIR);
  const chromiumExe = resolveChromium({ cli: options.chromium, revision: shell.revision });

  const server = await startServer(DESIGN_DIR);
  let status = 0;
  try {
    const router = await createOfflineRouter({ designDir: DESIGN_DIR, modulesDir: MODULES_DIR, origin: server.origin });
    for (const label of router.scriptLabels) log(`local copy: ${label}`);
    log(
      chromiumExe.executablePath
        ? `browser: ${chromiumExe.executablePath} (from ${chromiumExe.source})`
        : `browser: ${chromiumExe.source} (not found: ${chromiumExe.tried.join(', ') || 'no candidate on this platform'})`,
    );
    log(`rendering ${targets.length} board(s) with ${options.jobs} job(s) into ${options.out}`);

    const diffDir = path.join(options.out, '_diffs');
    const secondDir = path.join(options.out, '_second');
    await rm(diffDir, { recursive: true, force: true });
    const passOptions = { router, origin: server.origin, jobs: options.jobs, log, executablePath: chromiumExe.executablePath };
    const pass = await renderPass(targets, options.out, { ...passOptions, label: '' });
    const rendered = pass.results.size;
    const failures = [...pass.failures];

    let mismatches = [];
    let secondMs = 0;
    if (options.twice && rendered > 0) {
      await rm(secondDir, { recursive: true, force: true });
      try {
        const again = targets.filter((t) => pass.results.has(t.id));
        const second = await renderPass(again, secondDir, { ...passOptions, label: 'second ' });
        secondMs = second.ms;
        failures.push(...second.failures.map((f) => ({ ...f, reason: `second render: ${f.reason}` })));
        mismatches = await comparePasses(pass.results, second.results, options.out, secondDir, diffDir);
      } finally {
        await rm(secondDir, { recursive: true, force: true });
      }
    }

    // A board that failed in either render, or rendered differently twice, is no reference: its
    // PNG goes (a mismatch keeps both renders in _diffs/) and so does its manifest entry.
    for (const id of new Set([...failures, ...mismatches].map((f) => f.id))) {
      pass.results.delete(id);
      await rm(path.join(options.out, `${id}.png`), { force: true });
    }
    await writeManifest(options.out, [...list.boards, ...list.pages], pass);

    // Count check: one PNG per requested board, or the run fails.
    const { missing, error: countError } = countCheck(targets, pass.results);
    const misses = [...new Set(server.misses)].filter((m) => m !== '/favicon.ico');
    log('');
    log(`rendered ${rendered} of ${targets.length} board(s) in ${seconds(pass.ms)} (chromium ${pass.browserVersion})`);
    const { scripts, stylesheets, fontFiles } = router.served;
    log(`served locally: ${scripts} script(s), ${stylesheets} font stylesheet(s), ${fontFiles} font file(s)`);
    if (pass.browserVersion !== shell.version) {
      console.error(
        `WARNING: chromium ${pass.browserVersion} is not ${shell.version} (revision ${shell.revision}), ` +
          'the browser playwright-core expects; references from it are not comparable',
      );
    }
    for (const f of failures) console.error(`FAILED ${f.id} (${f.file}): ${f.reason}`);
    for (const v of router.violations) console.error(`BLOCKED ${v.url}: ${v.reason}`);
    for (const m of misses) console.error(`NOT FOUND in design/: ${m}`);
    if (options.twice) {
      if (mismatches.length === 0) log(`twice: all ${rendered} PNG(s) identical (second render ${seconds(secondMs)})`);
      for (const m of mismatches) console.error(`NOT DETERMINISTIC ${m.id}: ${m.reason}`);
    }
    if (countError !== null) console.error(countError);
    status = runStatus({ failures, missing, violations: router.violations, misses, mismatches });
  } finally {
    await server.close();
  }
  return status;
}

if (process.argv[2] === 'compare') {
  // compareMain reports its own errors and resolves to the exit code.
  compareMain(process.argv.slice(3), { repoDir: REPO_DIR, toolDir: TOOL_DIR }).then((code) => {
    process.exitCode = code;
  });
} else {
  main().then(
    (code) => {
      process.exitCode = code;
    },
    (error) => {
      if (error instanceof UsageError) {
        console.error(`design-refs: ${error.message}\n\n${USAGE}`);
        process.exitCode = 2;
      } else {
        console.error(`design-refs: ${error instanceof Error ? error.message : String(error)}`);
        process.exitCode = 1;
      }
    },
  );
}
