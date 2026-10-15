// Offline request routing for the browser.
//
// The design export loads three things from the internet at run time (G07):
//   - React, ReactDOM and Babel standalone from unpkg.com (design/support.js), with SRI hashes;
//   - 13 font families from fonts.googleapis.com/css2 (design/ds-additions/fm-additions.css).
// Here those requests are answered from the npm packages pinned in package-lock.json: unpkg URLs
// from node_modules, the css2 stylesheet as @font-face rules generated from the @fontsource
// packages, and the font files those rules point at (under fonts.gstatic.com/fontsource/, a path
// the real host does not use). The local design server passes through. Every other request is
// aborted and recorded, and the caller fails the run.

import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';

/** Prefix of the font file URLs in the generated stylesheet. */
export const FONT_FILE_PREFIX = 'https://fonts.gstatic.com/fontsource/';

const FONT_DISPLAY_VALUES = new Set(['auto', 'block', 'swap', 'fallback', 'optional']);

/** CORS header: the design scripts carry `crossorigin="anonymous"`, and web fonts are CORS requests. */
const CORS = { 'access-control-allow-origin': '*' };

/**
 * Finds the unpkg scripts in design/support.js (`var X_URL = "https://unpkg.com/…"` with an
 * optional `var X_SRI = "sha384-…"`), maps each to its file in node_modules, checks that the
 * installed package has the version in the URL and that the file matches the SRI hash, and
 * returns the file contents by URL.
 *
 * @param {string} designDir
 * @param {string} modulesDir
 * @returns {Promise<Map<string, {body: Buffer, label: string}>>}
 */
export async function loadUnpkgScripts(designDir, modulesDir) {
  const support = await readFile(path.join(designDir, 'support.js'), 'utf8');
  const found = [...support.matchAll(/var (\w+)_URL = "(https:\/\/unpkg\.com\/[^"]+)";(?:\s*var \1_SRI = "([^"]+)";)?/g)];
  if (found.length === 0) throw new Error('design/support.js names no unpkg.com script; the export format changed');
  const scripts = new Map();
  for (const [, , url, sri] of found) {
    const m = /^https:\/\/unpkg\.com\/((?:@[^/@]+\/)?[^/@]+)@([^/]+)\/(.+)$/.exec(url);
    if (!m) throw new Error(`design/support.js: cannot map ${url} to an npm package`);
    const [, name, version, file] = m;
    const pkgDir = path.join(modulesDir, ...name.split('/'));
    const installed = JSON.parse(await readFile(path.join(pkgDir, 'package.json'), 'utf8')).version;
    if (installed !== version) {
      throw new Error(`design/support.js loads ${name}@${version}, but ${installed} is installed; pin ${version} in package.json`);
    }
    const body = await readFile(path.join(pkgDir, ...file.split('/')));
    if (sri) {
      const [algo] = sri.split('-', 1);
      const actual = `${algo}-${createHash(algo).update(body).digest('base64')}`;
      if (actual !== sri) throw new Error(`${name}@${version}/${file}: SRI mismatch (design ${sri}, local ${actual})`);
    }
    scripts.set(url, { body, label: `${name}@${version}/${file}${sri ? ' (SRI ok)' : ''}` });
  }
  return scripts;
}

/**
 * Parses the `family` parameters of a Google Fonts css2 URL into faces.
 *
 * `IBM Plex Sans JP:wght@400;500`, `EB Garamond:ital,wght@0,400;1,400` and a bare `Homemade Apple`
 * (weight 400, normal) are understood; ranges and other axes are rejected.
 *
 * @param {URLSearchParams} params
 * @returns {Array<{family: string, faces: Array<{style: 'normal' | 'italic', weight: number}>}>}
 */
export function parseCss2Query(params) {
  const specs = params.getAll('family');
  if (specs.length === 0) throw new Error('css2 request without a family');
  return specs.map((spec) => {
    const colon = spec.indexOf(':');
    const family = (colon < 0 ? spec : spec.slice(0, colon)).trim();
    if (!/^[A-Za-z0-9 ]+$/.test(family)) throw new Error(`bad family name "${family}"`);
    if (colon < 0) return { family, faces: [{ style: 'normal', weight: 400 }] };
    const axisSpec = spec.slice(colon + 1);
    const at = axisSpec.indexOf('@');
    if (at < 0) throw new Error(`${family}: axis list without values`);
    const axes = axisSpec.slice(0, at).split(',');
    if (!axes.every((a) => a === 'ital' || a === 'wght') || new Set(axes).size !== axes.length) {
      throw new Error(`${family}: unsupported axes "${axes.join(',')}"`);
    }
    const faces = axisSpec
      .slice(at + 1)
      .split(';')
      .map((tuple) => {
        const values = tuple.split(',');
        if (values.length !== axes.length) throw new Error(`${family}: bad tuple "${tuple}"`);
        const face = { style: /** @type {'normal' | 'italic'} */ ('normal'), weight: 400 };
        axes.forEach((axis, i) => {
          const v = values[i];
          if (axis === 'ital') {
            if (v !== '0' && v !== '1') throw new Error(`${family}: bad ital value "${v}"`);
            face.style = v === '1' ? 'italic' : 'normal';
          } else {
            if (!/^[1-9]00$/.test(v)) throw new Error(`${family}: unsupported weight "${v}" (static weights only)`);
            face.weight = Number(v);
          }
        });
        return face;
      });
    return { family, faces };
  });
}

/** The @fontsource package name for a Google Fonts family: "IBM Plex Sans JP" → "ibm-plex-sans-jp". */
export function fontsourcePackage(family) {
  return family.toLowerCase().replace(/ +/g, '-');
}

/**
 * Builds the stylesheet a css2 request would return, from the @fontsource packages.
 *
 * Each requested face takes the package's own `<weight>[-italic].css` (all subsets, with their
 * unicode ranges) and points its `url(./files/…)` sources at [FONT_FILE_PREFIX].
 *
 * @param {URLSearchParams} params
 * @param {{modulesDir: string, packages: Set<string>}} options packages: allowed @fontsource names
 * @returns {Promise<string>}
 */
export async function buildFontCss(params, { modulesDir, packages }) {
  const display = params.get('display');
  if (display !== null && !FONT_DISPLAY_VALUES.has(display)) throw new Error(`bad display value "${display}"`);
  const parts = [];
  for (const { family, faces } of parseCss2Query(params)) {
    const pkg = fontsourcePackage(family);
    if (!packages.has(pkg)) throw new Error(`no @fontsource/${pkg} dependency for "${family}"; add it to package.json`);
    const pkgDir = path.join(modulesDir, '@fontsource', pkg);
    const { version } = JSON.parse(await readFile(path.join(pkgDir, 'package.json'), 'utf8'));
    for (const { style, weight } of faces) {
      const name = `${weight}${style === 'italic' ? '-italic' : ''}.css`;
      let css;
      try {
        css = await readFile(path.join(pkgDir, name), 'utf8');
      } catch {
        throw new Error(`@fontsource/${pkg}@${version} has no ${name} for ${family} ${weight} ${style}`);
      }
      if (!css.includes(`font-family: '${family}';`)) {
        throw new Error(`@fontsource/${pkg}/${name} does not declare font-family '${family}'`);
      }
      css = css.replace(/url\(\.\/files\/([a-z0-9-]+\.woff2?)\)/g, `url(${FONT_FILE_PREFIX}${pkg}/$1)`);
      if (display !== null) css = css.replace(/font-display: [a-z]+;/g, `font-display: ${display};`);
      parts.push(`/* ${family} ${weight} ${style}: @fontsource/${pkg}@${version}/${name} */\n${css.trim()}\n`);
    }
  }
  return parts.join('\n');
}

/**
 * Creates the router. `install(context, onViolation)` routes every request of a Playwright
 * browser context; a blocked request is recorded in `violations` and also passed to that
 * context's `onViolation`, so the board being rendered can fail.
 *
 * @param {{designDir: string, modulesDir: string, origin: string}} options
 *   origin: the local design server, the only origin that may reach the network stack
 * @returns {Promise<{
 *   install: (
 *     context: import('playwright-core').BrowserContext,
 *     onViolation?: (violation: {url: string, reason: string}) => void,
 *   ) => Promise<void>,
 *   violations: Array<{url: string, reason: string}>,
 *   served: {scripts: number, stylesheets: number, fontFiles: number},
 *   scriptLabels: string[],
 * }>}
 */
export async function createOfflineRouter({ designDir, modulesDir, origin }) {
  const scripts = await loadUnpkgScripts(designDir, modulesDir);
  const manifest = JSON.parse(await readFile(path.join(modulesDir, '..', 'package.json'), 'utf8'));
  const packages = new Set(
    Object.keys(manifest.dependencies ?? {})
      .filter((n) => n.startsWith('@fontsource/'))
      .map((n) => n.slice('@fontsource/'.length)),
  );
  const fontFiles = new Map();
  const violations = [];
  const served = { scripts: 0, stylesheets: 0, fontFiles: 0 };

  async function readFontFile(pathname) {
    const m = /^\/fontsource\/([a-z0-9-]+)\/([a-z0-9-]+\.woff2?)$/.exec(pathname);
    if (!m || !packages.has(m[1])) throw new Error('not a pinned @fontsource file');
    const file = path.join(modulesDir, '@fontsource', m[1], 'files', m[2]);
    let body = fontFiles.get(file);
    if (!body) {
      body = await readFile(file);
      fontFiles.set(file, body);
    }
    return { body, contentType: m[2].endsWith('.woff2') ? 'font/woff2' : 'font/woff' };
  }

  const stylesheets = new Map();

  /** The response for an allowed request; throws for anything else. */
  async function respond(request, url) {
    if (request.method() !== 'GET') throw new Error(`method ${request.method()} is not allowed`);
    if (url.host === 'unpkg.com') {
      const script = scripts.get(url.href);
      if (!script) throw new Error('not one of the scripts design/support.js pins');
      served.scripts += 1;
      return { status: 200, headers: { ...CORS, 'content-type': 'text/javascript; charset=utf-8' }, body: script.body };
    }
    if (url.host === 'fonts.googleapis.com' && url.pathname === '/css2') {
      let css = stylesheets.get(url.search);
      if (css === undefined) {
        css = await buildFontCss(url.searchParams, { modulesDir, packages });
        stylesheets.set(url.search, css);
      }
      served.stylesheets += 1;
      return { status: 200, headers: { ...CORS, 'content-type': 'text/css; charset=utf-8' }, body: css };
    }
    if (url.href.startsWith(FONT_FILE_PREFIX)) {
      const { body, contentType } = await readFontFile(url.pathname);
      served.fontFiles += 1;
      return { status: 200, headers: { ...CORS, 'content-type': contentType }, body };
    }
    throw new Error('not an allowed host or path');
  }

  /**
   * @param {import('playwright-core').Route} route
   * @param {((violation: {url: string, reason: string}) => void) | undefined} onViolation
   */
  async function handle(route, onViolation) {
    const request = route.request();
    const url = new URL(request.url());
    // Errors from continue, fulfill and abort only mean the page has already gone.
    const ignore = () => {};
    if (url.origin === origin) return route.continue().catch(ignore);
    let response;
    try {
      response = await respond(request, url);
    } catch (error) {
      const violation = { url: request.url(), reason: error instanceof Error ? error.message : String(error) };
      violations.push(violation);
      onViolation?.(violation);
      return route.abort('blockedbyclient').catch(ignore);
    }
    return route.fulfill(response).catch(ignore);
  }

  return {
    install: (context, onViolation) => context.route('**/*', (route) => handle(route, onViolation)),
    violations,
    served,
    scriptLabels: [...scripts.values()].map((s) => s.label),
  };
}
