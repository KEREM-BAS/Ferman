import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

import { check, checkRender, resolveChromium } from '../index.mjs';
import {
  LOGO_DIR,
  LOGO_FILES,
  SMALL_MARK_MAX,
  cleanSvg,
  faviconSvg,
  icoSizes,
  markSvg,
  outputs,
  packIco,
  pngSize,
  readLogo,
  sourceHash,
} from '../icons.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const hasLogo = LOGO_FILES.every((name) => existsSync(path.join(root, LOGO_DIR, name)));
const skipLogo = hasLogo ? false : `${LOGO_DIR} is not in this checkout`;

function logoFiles() {
  return Object.fromEntries(LOGO_FILES.map((name) => [name, cleanSvg(readFileSync(path.join(root, LOGO_DIR, name), 'utf8'))]));
}

/** A PNG of `width` × `height` RGBA pixels, every byte `fill`. */
function png(width, height, fill = 0, colorType = 6) {
  const channels = colorType === 6 ? 4 : 3;
  const chunk = (type, data) => {
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length);
    return Buffer.concat([length, Buffer.from(type, 'latin1'), data, Buffer.alloc(4)]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr.writeUInt8(8, 8);
  ihdr.writeUInt8(colorType, 9);
  const rows = [];
  for (let y = 0; y < height; y++) rows.push(Buffer.from([0]), Buffer.alloc(width * channels, fill));
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(Buffer.concat(rows))),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

test('reads the logo export into its shapes and the design colours', { skip: skipLogo }, () => {
  const logo = readLogo(logoFiles());
  assert.deepEqual(logo.colors, {
    seal: '#B5372A',
    sealDark: '#E0675A',
    soot: '#161615',
    paper: '#F7F6F3',
    tile: '#1D1C1B',
  });
  assert.equal(logo.ringWidth, '1.6');
  assert.match(logo.seal, /^M50 4 /);
});

test('stops when the logo export changes shape', { skip: skipLogo }, () => {
  const files = logoFiles();
  files['ferman-mark-small.svg'] = files['ferman-mark-small.svg'].replace('M36 38', 'M37 38');
  assert.throws(() => readLogo(files), /the logo export changed[\s\S]*ferman-mark-mono\.svg: the path is not the small mark/);
});

test('draws the small mark up to 32 px and the full mark above', { skip: skipLogo }, () => {
  const logo = readLogo(logoFiles());
  assert.match(markSvg(logo, SMALL_MARK_MAX, '#B5372A'), /fill-rule="evenodd"/);
  assert.doesNotMatch(markSvg(logo, SMALL_MARK_MAX, '#B5372A'), /<mask/);
  assert.match(markSvg(logo, SMALL_MARK_MAX + 1, '#B5372A'), /<mask id="cut"/);
  assert.match(faviconSvg(logo), /prefers-color-scheme:dark\)\{path\{fill:#E0675A\}/);
});

test('lists each output once, the Windows icon with its ten sizes', { skip: skipLogo }, () => {
  const list = outputs(readLogo(logoFiles()));
  const paths = list.map((output) => output.path);
  assert.equal(new Set(paths).size, paths.length);
  const ico = list.find((output) => output.kind === 'ico');
  assert.deepEqual(
    ico.images.map((image) => image.size),
    [16, 20, 24, 32, 40, 48, 64, 96, 128, 256],
  );
  assert.ok(paths.every((p) => p.startsWith('app/')), 'every icon goes into the app');
});

test('packs PNGs into an ICO and reads the sizes back', () => {
  const ico = packIco([png(16, 16), png(48, 48), png(256, 256)]);
  assert.deepEqual(icoSizes(ico), [
    { width: 16, height: 16 },
    { width: 48, height: 48 },
    { width: 256, height: 256 },
  ]);
  assert.equal(ico.readUInt32LE(6 + 12), 6 + 3 * 16, 'the first image follows the directory');
  assert.throws(() => packIco([png(512, 512)]), /at most 256/);
  assert.throws(() => pngSize(Buffer.from('not a png')), /not a PNG/);
});

test('rejects an empty render and one without alpha', () => {
  assert.match(checkRender(png(4, 4, 0)), /empty/);
  assert.equal(checkRender(png(4, 4, 200)), null);
  assert.match(checkRender(png(4, 4, 200, 2)), /no alpha channel/);
  assert.equal(checkRender(png(4, 4, 200, 2), true), null, 'an opaque icon may come without alpha');
});

test('takes the browser from --chromium, then FERMAN_CHROMIUM, then an installed one', () => {
  const exists = (p) => p === '/given' || p === '/usr/bin/chromium';
  assert.equal(resolveChromium('/given', {}, 'linux', exists), '/given');
  assert.equal(resolveChromium(undefined, { FERMAN_CHROMIUM: '/given' }, 'linux', exists), '/given');
  assert.equal(resolveChromium(undefined, {}, 'linux', exists), '/usr/bin/chromium');
  assert.throws(() => resolveChromium('/missing', {}, 'linux', exists), /--chromium: there is no browser/);
  assert.throws(() => resolveChromium(undefined, {}, 'linux', () => false), /no Chrome or Chromium found/);
});

test('hashes a CRLF checkout of a logo file like the LF one', () => {
  assert.equal(sourceHash('<svg>\r\n</svg>\r\n'), sourceHash('<svg>\n</svg>\n'));
});

test('the committed icons match the logo export and the manifest', { skip: skipLogo }, async () => {
  assert.deepEqual(await check(root), []);
});
