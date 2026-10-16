import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { FONT_FILE_PREFIX, buildFontCss, fontsourcePackage, loadUnpkgScripts, parseCss2Query } from '../routes.mjs';

const TOOL_DIR = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const DESIGN_DIR = path.join(TOOL_DIR, '..', '..', 'design');
const MODULES_DIR = path.join(TOOL_DIR, 'node_modules');

/** The query of the Google Fonts @import in design/ds-additions/fm-additions.css. */
async function designFontQuery() {
  const css = await readFile(path.join(DESIGN_DIR, 'ds-additions', 'fm-additions.css'), 'utf8');
  const m = /@import url\('(https:\/\/fonts\.googleapis\.com\/css2\?[^']+)'\)/.exec(css);
  assert.ok(m, 'fm-additions.css imports from fonts.googleapis.com');
  return new URL(m[1]).searchParams;
}

async function fontPackages() {
  const pkg = JSON.parse(await readFile(path.join(TOOL_DIR, 'package.json'), 'utf8'));
  return new Set(
    Object.keys(pkg.dependencies)
      .filter((n) => n.startsWith('@fontsource/'))
      .map((n) => n.slice('@fontsource/'.length)),
  );
}

test('parses the design import into 13 families with their faces', async () => {
  const families = parseCss2Query(await designFontQuery());
  assert.equal(families.length, 13);
  const byName = Object.fromEntries(families.map((f) => [f.family, f.faces]));
  assert.deepEqual(byName['IBM Plex Sans JP'], [
    { style: 'normal', weight: 400 },
    { style: 'normal', weight: 500 },
    { style: 'normal', weight: 600 },
  ]);
  assert.deepEqual(byName['EB Garamond'], [
    { style: 'normal', weight: 400 },
    { style: 'normal', weight: 600 },
    { style: 'italic', weight: 400 },
  ]);
  assert.deepEqual(byName['Homemade Apple'], [{ style: 'normal', weight: 400 }]);
  assert.deepEqual(byName.Caveat, [{ style: 'normal', weight: 500 }]);
});

test('every imported family has a pinned @fontsource package', async () => {
  const packages = await fontPackages();
  for (const { family } of parseCss2Query(await designFontQuery())) {
    assert.ok(packages.has(fontsourcePackage(family)), family);
  }
  assert.equal(packages.size, 13);
});

test('rejects what the generator does not understand', () => {
  const q = (s) => new URLSearchParams(s);
  assert.throws(() => parseCss2Query(q('display=swap')), /without a family/);
  assert.throws(() => parseCss2Query(q('family=Caveat:wght@400..700')), /static weights only/);
  assert.throws(() => parseCss2Query(q('family=Caveat:opsz,wght@12,400')), /unsupported axes/);
  assert.throws(() => parseCss2Query(q('family=Caveat:ital,wght@1')), /bad tuple/);
  assert.throws(() => parseCss2Query(q('family=../evil')), /bad family name/);
});

test('builds @font-face rules that point only at local font files', async () => {
  const css = await buildFontCss(await designFontQuery(), { modulesDir: MODULES_DIR, packages: await fontPackages() });
  assert.ok(!css.includes('./files/'));
  const urls = [...css.matchAll(/url\(([^)]+)\)/g)].map((m) => m[1]);
  assert.ok(urls.length > 100);
  for (const url of urls) assert.ok(url.startsWith(FONT_FILE_PREFIX), url);
  for (const family of ['Homemade Apple', 'Noto Naskh Arabic', 'IBM Plex Sans Devanagari', 'Noto Sans SC']) {
    assert.ok(css.includes(`font-family: '${family}';`), family);
  }
  assert.ok(/font-family: 'EB Garamond';\s+font-style: italic;/.test(css));
  assert.ok(!/font-display: (?!swap)/.test(css));
});

test('refuses families that are not pinned', async () => {
  await assert.rejects(
    buildFontCss(new URLSearchParams('family=Roboto'), { modulesDir: MODULES_DIR, packages: await fontPackages() }),
    /no @fontsource\/roboto dependency/,
  );
});

test('the unpkg scripts design/support.js loads are pinned and match their SRI hashes', async () => {
  const scripts = await loadUnpkgScripts(DESIGN_DIR, MODULES_DIR);
  assert.deepEqual([...scripts.keys()].sort(), [
    'https://unpkg.com/@babel/standalone@7.29.0/babel.min.js',
    'https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js',
    'https://unpkg.com/react@18.3.1/umd/react.production.min.js',
  ]);
  for (const { label } of scripts.values()) assert.ok(label.endsWith('(SRI ok)'), label);
});
