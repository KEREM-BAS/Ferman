import assert from 'node:assert/strict';
import { mkdir, mkdtemp, realpath, rm, symlink, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { loadBoards } from '../boards.mjs';
import { UsageError, isCaseInsensitiveDir, isInsideDir, parseCli, realpathOfNearest, selectTargets } from '../cli.mjs';

const TOOL_DIR = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const defaults = { defaultOut: path.join(os.tmpdir(), 'refs') };

test('parses the options', () => {
  const o = parseCli(['--only', 'a1-1, a1-2b', '--only', '@m1', '--twice', '--jobs', '2', '--chromium', 'shell'], defaults);
  assert.deepEqual(o.only, ['a1-1', 'a1-2b', '@m1']);
  assert.equal(o.twice, true);
  assert.equal(o.jobs, 2);
  assert.equal(o.chromium, path.resolve('shell'));
  assert.equal(o.out, defaults.defaultOut);
  const d = parseCli([], defaults);
  assert.equal(d.chromium, undefined);
  assert.deepEqual(d.only, []);
  assert.equal(d.twice, false);
});

test('rejects bad options as usage errors', () => {
  for (const argv of [['--jobs', '0'], ['--jobs', 'x'], ['--chromium', ''], ['--nope'], ['positional']]) {
    assert.throws(() => parseCli(argv, defaults), UsageError, argv.join(' '));
  }
});

test('selects boards by id and set, in boards.json order', async () => {
  const list = await loadBoards(path.join(TOOL_DIR, 'boards.json'));
  const m1 = selectTargets(list, ['@m1']);
  // 23 boards, 5 of them (the M1 build boards) also in Turkish and Arabic.
  assert.equal(m1.length, 33);
  const order = [...list.boards, ...list.pages].map((b) => b.id);
  assert.deepEqual(
    [...new Set(m1.map((t) => t.board))],
    order.filter((id) => list.sets.m1.includes(id)),
  );
  assert.deepEqual(
    selectTargets(list, ['ds-additions', 'a1-1']).map((b) => b.id),
    ['a1-1', 'ds-additions'],
  );
  // A board id brings its variants, a variant id only itself.
  assert.deepEqual(
    selectTargets(list, ['a1-9c']).map((t) => t.id),
    ['a1-9c', 'a1-9c.tr', 'a1-9c.ar'],
  );
  assert.deepEqual(
    selectTargets(list, ['a1-9c.ar', 'a1-1']).map((t) => [t.id, t.board, t.lang]),
    [
      ['a1-1', 'a1-1', undefined],
      ['a1-9c.ar', 'a1-9c', 'ar'],
    ],
  );
  assert.equal(selectTargets(list, ['@langs']).length, 3 * list.sets.langs.length);
  assert.equal(selectTargets(list, ['@m2']).filter((t) => t.lang === undefined).length, 43);
  const variants = list.boards.reduce((n, b) => n + (b.langs?.length ?? 0), 0);
  assert.equal(variants, 58);
  assert.equal(selectTargets(list, []).length, list.boards.length + variants + list.pages.length);
  assert.throws(() => selectTargets(list, ['a0-0']), UsageError);
  assert.throws(() => selectTargets(list, ['a1-1.tr']), UsageError);
  assert.throws(() => selectTargets(list, ['@nope']), UsageError);
});

let base;

before(async () => {
  base = await realpath(await mkdtemp(path.join(os.tmpdir(), 'design-refs-cli-')));
  await mkdir(path.join(base, 'repo', 'design', 'sub'), { recursive: true });
  await mkdir(path.join(base, 'repo', 'build'), { recursive: true });
  await writeFile(path.join(base, 'repo', 'file.txt'), 'x');
  if (process.platform !== 'win32') {
    await symlink(path.join(base, 'repo', 'design'), path.join(base, 'repo', 'link'));
    await symlink(path.join(base, 'repo', 'design', 'sub'), path.join(base, 'repo', 'build', 'sublink'));
  }
});

after(async () => {
  await rm(base, { recursive: true, force: true });
});

test('real path of a folder that does not exist yet', () => {
  const repo = path.join(base, 'repo');
  assert.equal(realpathOfNearest(path.join(repo, 'build', 'a', 'b')), path.join(repo, 'build', 'a', 'b'));
  assert.equal(realpathOfNearest(path.join(repo, 'file.txt', 'x')), path.join(repo, 'file.txt', 'x'));
  if (process.platform !== 'win32') {
    assert.equal(realpathOfNearest(path.join(repo, 'link', 'new', 'dir')), path.join(repo, 'design', 'new', 'dir'));
  }
});

test('--out guard: inside design/ or not', () => {
  const repo = path.join(base, 'repo');
  const design = path.join(repo, 'design');
  const inside = (p, o) => isInsideDir(path.join(repo, p), design, o);
  assert.equal(inside('design'), true);
  assert.equal(inside('design/sub'), true);
  assert.equal(inside('design/new/refs'), true);
  assert.equal(inside('build/../design/x'), true);
  assert.equal(inside('build/design-refs'), false);
  assert.equal(inside('design-refs'), false);
  assert.equal(inside('design/../build'), false);
  assert.equal(inside('.'), false);
  if (process.platform !== 'win32') {
    assert.equal(inside('link'), true, 'symlink to design/');
    assert.equal(inside('link/new/refs'), true, 'new folder under a symlink to design/');
    assert.equal(inside('build/sublink/refs'), true, 'symlink into design/');
  }
});

test('--out guard: case-insensitive filesystems', () => {
  const repo = path.join(base, 'repo');
  const design = path.join(repo, 'design');
  assert.equal(isInsideDir(path.join(repo, 'Design', 'refs'), design, { caseInsensitive: true }), true);
  assert.equal(isInsideDir(path.join(repo, 'DESIGN'), design, { caseInsensitive: true }), true);
  assert.equal(isInsideDir(path.join(repo, 'Design-refs'), design, { caseInsensitive: true }), false);
  assert.equal(isInsideDir(path.join(repo, 'Design', 'refs'), design, { caseInsensitive: false }), false);
});

test('detects whether the filesystem ignores case', async () => {
  const design = path.join(base, 'repo', 'design');
  const upper = path.join(base, 'repo', 'DESIGN');
  let insensitive;
  try {
    await mkdir(upper);
    insensitive = false; // a second folder could be made, so names are case-sensitive here
    await rm(upper, { recursive: true });
  } catch {
    insensitive = true; // EEXIST: "DESIGN" is the existing "design"
  }
  assert.equal(isCaseInsensitiveDir(design), insensitive);
  assert.equal(isInsideDir(upper, design), insensitive);
});
