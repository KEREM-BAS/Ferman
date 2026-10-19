// The logo export, the icon artwork drawn from it, and the files each platform takes.
//
// Everything here is pure: reading the logo is string parsing, the artwork is SVG text, and the
// ICO and PNG helpers work on buffers. index.mjs renders the SVGs with a headless Chromium.

import { createHash } from 'node:crypto';

/** The logo export (design/assets/logo), relative to the repository root. */
export const LOGO_DIR = 'design/assets/logo';

/** The files of the logo export this tool reads. */
export const LOGO_FILES = [
  'favicon.svg',
  'ferman-app-icon-1024.svg',
  'ferman-app-icon-dark-1024.svg',
  'ferman-mark-dark.svg',
  'ferman-mark-mono.svg',
  'ferman-mark-small.svg',
  'ferman-mark.svg',
];

/**
 * Sizes up to this many pixels draw the small mark: the seal without its inner ring and a heavier
 * F, as the logo board's size test does (`px <= 32`).
 */
export const SMALL_MARK_MAX = 32;

/** The SVG text of a logo file with its C2PA `<metadata>` element removed and LF line ends. */
export function cleanSvg(text) {
  return text.replace(/\r\n?/g, '\n').replace(/<metadata>[\s\S]*?<\/metadata>/g, '');
}

/** SHA-256 of a logo file's text with LF line ends, so a CRLF checkout hashes the same. */
export function sourceHash(text) {
  return createHash('sha256').update(text.replace(/\r\n?/g, '\n')).digest('hex');
}

/** SHA-256 of a buffer. */
export function sha256(buffer) {
  return createHash('sha256').update(buffer).digest('hex');
}

/** The elements of a cleaned SVG: `[{name, attrs}]` for each `rect`, `g` and `path`, in order. */
export function elements(svg) {
  const found = [];
  for (const match of svg.matchAll(/<(rect|g|path)\b([^>]*)>/g)) {
    const attrs = {};
    for (const attr of match[2].matchAll(/([\w:-]+)="([^"]*)"/g)) attrs[attr[1]] = attr[2];
    found.push({ name: match[1], attrs });
  }
  return found;
}

const COLOR = /^#[0-9A-F]{6}$/;

/**
 * Reads the logo export into the parts the artwork is drawn from. `files` maps each name of
 * LOGO_FILES to its cleaned SVG text. Any change in the export's structure throws, so a new
 * logo is reviewed here instead of being drawn wrongly.
 *
 * @param {Record<string, string>} files
 */
export function readLogo(files) {
  const problems = [];
  const expect = (ok, message) => {
    if (!ok) problems.push(message);
  };
  const shape = (name, expected) => {
    const found = elements(files[name] ?? '');
    const names = found.map((e) => e.name).join(' ');
    expect(names === expected, `${name}: expected the elements "${expected}", found "${names}"`);
    return found;
  };

  const mark = shape('ferman-mark.svg', 'path path path');
  const [seal, ring, f] = mark.map((e) => e.attrs);
  const logo = {
    seal: seal?.d,
    ring: ring?.d,
    ringWidth: ring?.['stroke-width'],
    f: f?.d,
    colors: { seal: seal?.fill },
  };
  expect(ring?.fill === 'none' && ring?.stroke === '#FFFFFF', 'ferman-mark.svg: the ring is a white stroke');
  expect(f?.fill === '#FFFFFF', 'ferman-mark.svg: the F is white');

  const small = shape('ferman-mark-small.svg', 'path path').map((e) => e.attrs);
  logo.fSmall = small[1]?.d;
  expect(small[0]?.d === logo.seal && small[0]?.fill === logo.colors.seal, 'ferman-mark-small.svg: the seal differs from ferman-mark.svg');
  expect(small[1]?.fill === '#FFFFFF', 'ferman-mark-small.svg: the F is white');

  // The one-colour mark and the favicon are the small mark as one even-odd path: the F is a hole.
  for (const name of ['ferman-mark-mono.svg', 'favicon.svg']) {
    const [mono] = shape(name, 'path').map((e) => e.attrs);
    expect(mono?.['fill-rule'] === 'evenodd', `${name}: the path is not even-odd`);
    expect(mono?.d === `${logo.seal} ${logo.fSmall}`, `${name}: the path is not the small mark's seal and F`);
  }

  const dark = shape('ferman-mark-dark.svg', 'path path path').map((e) => e.attrs);
  logo.colors.sealDark = dark[0]?.fill;
  logo.colors.soot = dark[2]?.fill;
  expect(dark[0]?.d === logo.seal && dark[1]?.d === logo.ring && dark[2]?.d === logo.f, 'ferman-mark-dark.svg: the shapes differ from ferman-mark.svg');

  for (const [name, background, sealColor] of [
    ['ferman-app-icon-1024.svg', 'paper', 'seal'],
    ['ferman-app-icon-dark-1024.svg', 'tile', 'sealDark'],
  ]) {
    const icon = shape(name, 'rect g path path path').map((e) => e.attrs);
    logo.colors[background] = icon[0]?.fill;
    expect(icon[0]?.width === '1024' && icon[0]?.height === '1024', `${name}: the background is not 1024 × 1024`);
    expect(icon[1]?.transform === 'translate(212 212) scale(6)', `${name}: the mark is not placed at translate(212 212) scale(6)`);
    expect(icon[2]?.d === logo.seal && icon[3]?.d === logo.ring && icon[4]?.d === logo.f, `${name}: the shapes differ from ferman-mark.svg`);
    expect(icon[2]?.fill === logo.colors[sealColor], `${name}: the seal colour differs from the mark's`);
    expect(icon[3]?.stroke === icon[0]?.fill && icon[4]?.fill === icon[0]?.fill, `${name}: the ring and F are not the background colour`);
  }

  for (const [key, value] of Object.entries(logo.colors)) {
    expect(COLOR.test(value ?? ''), `the colour "${key}" is not #RRGGBB: ${value}`);
  }
  expect(logo.ringWidth === '1.6', `ferman-mark.svg: the ring is ${logo.ringWidth} wide, not 1.6`);
  if (problems.length > 0) {
    throw new Error(`the logo export changed; review tools/app-icons before drawing it:\n  ${problems.join('\n  ')}`);
  }
  return logo;
}

const SVG_OPEN = (viewBox, size) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}" width="${size}" height="${size}">`;

/**
 * The mark alone on a transparent ground in `color`, with the inner ring and the F cut out, so
 * the surface behind it shows through, as the board's Windows and Linux tiles draw it (their F
 * and ring take the tile colour). Sizes up to SMALL_MARK_MAX draw the small mark.
 */
export function markSvg(logo, size, color) {
  if (size <= SMALL_MARK_MAX) {
    return `${SVG_OPEN('0 0 100 100', size)}<path fill-rule="evenodd" fill="${color}" d="${logo.seal} ${logo.fSmall}"/></svg>`;
  }
  return (
    `${SVG_OPEN('0 0 100 100', size)}<defs><mask id="cut" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">` +
    `<rect width="100" height="100" fill="#FFFFFF"/>` +
    `<path d="${logo.ring}" fill="none" stroke="#000000" stroke-width="${logo.ringWidth}"/>` +
    `<path d="${logo.f}" fill="#000000"/></mask></defs>` +
    `<path d="${logo.seal}" fill="${color}" mask="url(#cut)"/></svg>`
  );
}

/** The mark's paths inside an icon's 1024 grid, at the export's place (translate 212, scale 6). */
function markGroup(logo, size, sealColor, cutColor) {
  const inner =
    size <= SMALL_MARK_MAX
      ? `<path d="${logo.fSmall}" fill="${cutColor}"/>`
      : `<path d="${logo.ring}" fill="none" stroke="${cutColor}" stroke-width="${logo.ringWidth}"/><path d="${logo.f}" fill="${cutColor}"/>`;
  return `<g transform="translate(212 212) scale(6)"><path d="${logo.seal}" fill="${sealColor}"/>${inner}</g>`;
}

/**
 * The app icon edge to edge, as the export's ferman-app-icon-1024.svg draws it: for surfaces that
 * mask the icon themselves (web maskable icons, the Apple touch icon).
 */
export function fullBleedSvg(logo, size, dark = false) {
  const ground = dark ? logo.colors.tile : logo.colors.paper;
  const seal = dark ? logo.colors.sealDark : logo.colors.seal;
  return `${SVG_OPEN('0 0 1024 1024', size)}<rect width="1024" height="1024" fill="${ground}"/>${markGroup(logo, size, seal, ground)}</svg>`;
}

/**
 * The macOS app icon on Apple's 1024 grid: an 824-point rounded square 100 points in from each
 * edge, with a soft shadow below. The board's macOS tile (132 px, radius 30, a 96 px mark) scales
 * to that square with a 187-point radius and a 599-point mark, so the export's 600-point mark at
 * translate(212 212) sits in it unchanged; the radius is Apple's 185.4 (G112).
 */
export function macTileSvg(logo, size) {
  const { paper, seal } = logo.colors;
  return (
    `${SVG_OPEN('0 0 1024 1024', size)}<defs>` +
    `<filter id="shadow" x="0" y="0" width="1024" height="1024" filterUnits="userSpaceOnUse">` +
    `<feDropShadow dx="0" dy="10" stdDeviation="10" flood-color="#141311" flood-opacity="0.3"/></filter></defs>` +
    `<rect x="100" y="100" width="824" height="824" rx="185.4" fill="${paper}" filter="url(#shadow)"/>` +
    `<rect x="98.5" y="98.5" width="827" height="827" rx="186.9" fill="none" stroke="#000000" stroke-opacity="0.12" stroke-width="3"/>` +
    `${markGroup(logo, size, seal, paper)}</svg>`
  );
}

/**
 * The web favicon: the small mark as one even-odd path, so the tab shows through the F as the
 * board's tab strip draws it, in the seal colour, and in the lighter seal colour when the browser
 * is dark.
 */
export function faviconSvg(logo) {
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">` +
    `<style>path{fill:${logo.colors.seal}}@media (prefers-color-scheme:dark){path{fill:${logo.colors.sealDark}}}</style>` +
    `<path fill-rule="evenodd" d="${logo.seal} ${logo.fSmall}"/></svg>\n`
  );
}

/** Sizes in the Windows icon: the shell's standard sizes up to 256. */
export const WINDOWS_SIZES = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256];

/** The macOS asset catalog's files (Contents.json names them for each point size and scale). */
export const MAC_SIZES = [16, 32, 64, 128, 256, 512, 1024];

/**
 * Every file this tool writes, relative to the repository root. `kind` says how it is made:
 * `png` renders one SVG, `ico` packs one PNG per size, `text` is written as is. An `opaque` PNG
 * covers its whole square, so the browser may write it without an alpha channel.
 *
 * @param {ReturnType<typeof readLogo>} logo
 */
export function outputs(logo) {
  const { seal } = logo.colors;
  const mac = 'app/macos/Runner/Assets.xcassets/AppIcon.appiconset';
  return [
    ...MAC_SIZES.map((size) => ({ path: `${mac}/app_icon_${size}.png`, kind: 'png', size, svg: macTileSvg(logo, size) })),
    {
      path: 'app/windows/runner/resources/app_icon.ico',
      kind: 'ico',
      images: WINDOWS_SIZES.map((size) => ({ size, svg: markSvg(logo, size, seal) })),
    },
    { path: 'app/linux/runner/resources/app_icon.png', kind: 'png', size: 256, svg: markSvg(logo, 256, seal) },
    { path: 'app/web/favicon.svg', kind: 'text', text: faviconSvg(logo) },
    { path: 'app/web/favicon.png', kind: 'png', size: 32, svg: markSvg(logo, 32, seal) },
    { path: 'app/web/icons/Icon-192.png', kind: 'png', size: 192, svg: markSvg(logo, 192, seal) },
    { path: 'app/web/icons/Icon-512.png', kind: 'png', size: 512, svg: markSvg(logo, 512, seal) },
    { path: 'app/web/icons/Icon-maskable-192.png', kind: 'png', size: 192, opaque: true, svg: fullBleedSvg(logo, 192) },
    { path: 'app/web/icons/Icon-maskable-512.png', kind: 'png', size: 512, opaque: true, svg: fullBleedSvg(logo, 512) },
    { path: 'app/web/icons/apple-touch-icon.png', kind: 'png', size: 180, opaque: true, svg: fullBleedSvg(logo, 180) },
  ];
}

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/** Width and height from a PNG's IHDR chunk; throws when the buffer is not a PNG. */
export function pngSize(buffer) {
  if (buffer.length < 24 || !buffer.subarray(0, 8).equals(PNG_SIGNATURE) || buffer.toString('latin1', 12, 16) !== 'IHDR') {
    throw new Error('not a PNG file');
  }
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

/**
 * An ICO file holding each PNG as is (Windows Vista and later read PNG entries). Entries are
 * written in the order given; a 256-pixel side is stored as 0, as the format requires.
 *
 * @param {Buffer[]} pngs
 */
export function packIco(pngs) {
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(pngs.length, 4);
  const entries = [];
  let offset = 6 + 16 * pngs.length;
  for (const png of pngs) {
    const { width, height } = pngSize(png);
    if (width > 256 || height > 256) throw new Error(`an ICO image is at most 256 × 256, not ${width} × ${height}`);
    const entry = Buffer.alloc(16);
    entry.writeUInt8(width === 256 ? 0 : width, 0);
    entry.writeUInt8(height === 256 ? 0 : height, 1);
    entry.writeUInt8(0, 2); // no palette
    entry.writeUInt8(0, 3); // reserved
    entry.writeUInt16LE(1, 4); // colour planes
    entry.writeUInt16LE(32, 6); // bits per pixel
    entry.writeUInt32LE(png.length, 8);
    entry.writeUInt32LE(offset, 12);
    entries.push(entry);
    offset += png.length;
  }
  return Buffer.concat([header, ...entries, ...pngs]);
}

/** The sizes of an ICO file's images, as `[{width, height}]`, read from its directory. */
export function icoSizes(buffer) {
  if (buffer.length < 6 || buffer.readUInt16LE(0) !== 0 || buffer.readUInt16LE(2) !== 1) throw new Error('not an ICO file');
  const count = buffer.readUInt16LE(4);
  return Array.from({ length: count }, (_, i) => {
    const at = 6 + 16 * i;
    return { width: buffer.readUInt8(at) || 256, height: buffer.readUInt8(at + 1) || 256 };
  });
}
