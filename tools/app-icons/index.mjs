#!/usr/bin/env node
// Writes Ferman's app icons for macOS, Windows, Linux and the web from the logo export in
// design/assets/logo (G112). design/ is only read. See README.md.

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { inflateSync } from 'node:zlib';

import { LOGO_DIR, LOGO_FILES, cleanSvg, icoSizes, outputs, packIco, pngSize, readLogo, sha256, sourceHash } from './icons.mjs';

const USAGE = `Usage: node tools/app-icons [--check] [--chromium <path>] [--root <dir>]

Without --check, renders every icon with a headless Chromium and writes the files that changed,
then tools/app-icons/manifest.json. --check needs no browser: it exits 1 when the logo export
changed since the icons were made, or an icon is missing or differs from the manifest.

  --chromium <path>  The Chromium or Chrome executable. Default: FERMAN_CHROMIUM, then the usual
                     install places of Google Chrome and Chromium for this system.
  --root <dir>       The repository. Default: the one holding this tool.

Exit status: 0 success, 1 stale (--check), 2 the icons cannot be made, 64 bad usage.`;

const MANIFEST = 'tools/app-icons/manifest.json';
const PARALLEL = 4;

class UsageError extends Error {}

function parseArgs(argv) {
  const options = { check: false, chromium: undefined, root: undefined };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--check') options.check = true;
    else if (arg === '--chromium' || arg === '--root') {
      const value = argv[++i];
      if (value === undefined || value.startsWith('--')) throw new UsageError(`${arg} needs a value`);
      options[arg.slice(2)] = value;
    } else if (arg === '-h' || arg === '--help') options.help = true;
    else throw new UsageError(`unknown argument: ${arg}`);
  }
  return options;
}

/** The logo export's files, cleaned for reading, and the SHA-256 of each as committed. */
async function readSources(root) {
  const files = {};
  const hashes = {};
  for (const name of LOGO_FILES) {
    const file = path.join(root, LOGO_DIR, name);
    if (!existsSync(file)) throw new Error(`${LOGO_DIR}/${name} is missing`);
    const text = await readFile(file, 'utf8');
    files[name] = cleanSvg(text);
    hashes[name] = sourceHash(text);
  }
  return { files, hashes };
}

const BROWSERS = {
  darwin: [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
  ],
  win32: [
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  ],
  linux: ['/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser'],
};

/** The browser to render with: --chromium, FERMAN_CHROMIUM (each must exist), or an installed one. */
export function resolveChromium(cli, env = process.env, platform = process.platform, exists = existsSync) {
  for (const [value, source] of [
    [cli, '--chromium'],
    [env.FERMAN_CHROMIUM, 'FERMAN_CHROMIUM'],
  ]) {
    if (value === undefined || value === '') continue;
    if (!exists(value)) throw new Error(`${source}: there is no browser at ${value}`);
    return value;
  }
  const found = (BROWSERS[platform] ?? []).find((candidate) => exists(candidate));
  if (!found) throw new Error('no Chrome or Chromium found: pass --chromium <path> or set FERMAN_CHROMIUM');
  return found;
}

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => (stdout += chunk));
    child.stderr.on('data', (chunk) => (stderr += chunk));
    child.on('error', reject);
    child.on('close', (code) => resolve({ code, stdout, stderr }));
  });
}

/**
 * What is wrong with a rendered PNG, or null. An icon with transparent parts needs an 8-bit alpha
 * channel, and must draw something: a page whose SVG did not paint gives a fully transparent
 * screenshot. An opaque icon may come without alpha (the browser drops it when every pixel is
 * opaque).
 */
export function checkRender(buffer, opaque = false) {
  const { width } = pngSize(buffer);
  const colorType = buffer.readUInt8(25);
  const bitDepth = buffer.readUInt8(24);
  if (bitDepth !== 8) return `the render has ${bitDepth}-bit samples, not 8`;
  if (opaque && colorType === 2) return null;
  if (colorType !== 6) return 'the render has no alpha channel (PNG colour type 6)';
  const chunks = [];
  for (let at = 8; at < buffer.length; ) {
    const length = buffer.readUInt32BE(at);
    if (buffer.toString('latin1', at + 4, at + 8) === 'IDAT') chunks.push(buffer.subarray(at + 8, at + 8 + length));
    at += 12 + length;
  }
  const raw = inflateSync(Buffer.concat(chunks));
  const stride = 1 + width * 4;
  for (let i = 0; i < raw.length; i++) {
    if (i % stride !== 0 && raw[i] !== 0) return null;
  }
  return 'the render is empty: the page drew nothing';
}

async function renderPng(chromium, { svg, size, opaque }, workDir, name) {
  const html = path.join(workDir, `${name}.html`);
  const png = path.join(workDir, `${name}.png`);
  const profile = path.join(workDir, `${name}.profile`);
  await writeFile(
    html,
    '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;' +
      `background:transparent;overflow:hidden}svg{display:block}</style></head><body>${svg}</body></html>`,
  );
  const result = await run(chromium, [
    '--headless',
    '--disable-gpu',
    '--hide-scrollbars',
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-extensions',
    `--user-data-dir=${profile}`,
    '--force-device-scale-factor=1',
    '--force-color-profile=srgb',
    '--default-background-color=00000000',
    '--virtual-time-budget=1000',
    `--window-size=${size},${size}`,
    `--screenshot=${png}`,
    pathToFileURL(html).href,
  ]);
  if (!existsSync(png)) throw new Error(`${name}: the browser wrote no screenshot (exit ${result.code})\n${result.stderr.trim()}`);
  const buffer = await readFile(png);
  const { width, height } = pngSize(buffer);
  if (width !== size || height !== size) throw new Error(`${name}: rendered ${width} × ${height}, not ${size} × ${size}`);
  const problem = checkRender(buffer, opaque);
  if (problem) throw new Error(`${name}: ${problem}`);
  return buffer;
}

async function pool(tasks, limit) {
  const results = new Array(tasks.length);
  let next = 0;
  const worker = async () => {
    while (next < tasks.length) {
      const index = next++;
      results[index] = await tasks[index]();
    }
  };
  await Promise.all(Array.from({ length: Math.min(limit, tasks.length) }, worker));
  return results;
}

async function browserVersion(chromium) {
  try {
    const { stdout } = await run(chromium, ['--version']);
    return stdout.trim() || 'unknown';
  } catch {
    return 'unknown';
  }
}

/** Renders and writes every icon, then the manifest. */
async function generate(root, chromium, out) {
  const { files, hashes } = await readSources(root);
  const logo = readLogo(files);
  const list = outputs(logo);
  const workDir = await mkdtemp(path.join(os.tmpdir(), 'ferman-app-icons-'));
  try {
    const jobs = [];
    for (const output of list) {
      if (output.kind === 'png') jobs.push({ output, size: output.size, svg: output.svg, opaque: output.opaque });
      if (output.kind === 'ico') for (const image of output.images) jobs.push({ output, size: image.size, svg: image.svg });
    }
    const renders = await pool(
      jobs.map((job, i) => () => renderPng(chromium, job, workDir, `${i}-${job.size}`)),
      PARALLEL,
    );
    const manifest = { logo: hashes, renderer: await browserVersion(chromium), outputs: {} };
    let changed = 0;
    for (const output of list) {
      let bytes;
      if (output.kind === 'text') bytes = Buffer.from(output.text);
      else {
        const mine = renders.filter((_, i) => jobs[i].output === output);
        bytes = output.kind === 'ico' ? packIco(mine) : mine[0];
      }
      const file = path.join(root, output.path);
      const before = existsSync(file) ? await readFile(file) : null;
      if (!before?.equals(bytes)) {
        await mkdir(path.dirname(file), { recursive: true });
        await writeFile(file, bytes);
        out.write(`wrote ${output.path}\n`);
        changed++;
      }
      manifest.outputs[output.path] = { sha256: sha256(bytes), ...describe(output) };
    }
    await writeFile(path.join(root, MANIFEST), `${JSON.stringify(manifest, null, 2)}\n`);
    out.write(`${list.length} files, ${changed} changed; rendered with ${manifest.renderer}\n`);
  } finally {
    await rm(workDir, { recursive: true, force: true });
  }
}

function describe(output) {
  if (output.kind === 'png') return { size: output.size };
  if (output.kind === 'ico') return { sizes: output.images.map((image) => image.size) };
  return {};
}

/** The problems --check finds: an empty list means everything is current. */
export async function check(root) {
  const manifestFile = path.join(root, MANIFEST);
  if (!existsSync(manifestFile)) return [`${MANIFEST} is missing: run node tools/app-icons`];
  const manifest = JSON.parse(await readFile(manifestFile, 'utf8'));
  const { files, hashes } = await readSources(root);
  const logo = readLogo(files);
  const problems = [];
  for (const name of LOGO_FILES) {
    if (manifest.logo?.[name] !== hashes[name]) {
      problems.push(`${LOGO_DIR}/${name} changed since the icons were made: run node tools/app-icons`);
    }
  }
  const list = outputs(logo);
  for (const output of list) {
    const file = path.join(root, output.path);
    const recorded = manifest.outputs?.[output.path];
    if (!existsSync(file)) {
      problems.push(`${output.path} is missing`);
      continue;
    }
    const bytes = await readFile(file);
    if (output.kind === 'text') {
      if (bytes.toString('utf8').replace(/\r\n?/g, '\n') !== output.text) problems.push(`${output.path} is stale`);
      continue;
    }
    if (recorded?.sha256 !== sha256(bytes)) {
      problems.push(`${output.path} differs from ${MANIFEST}: run node tools/app-icons`);
      continue;
    }
    if (output.kind === 'png') {
      const { width, height } = pngSize(bytes);
      if (width !== output.size || height !== output.size) problems.push(`${output.path} is ${width} × ${height}, not ${output.size}`);
    } else {
      const sizes = icoSizes(bytes).map((s) => s.width);
      const expected = output.images.map((image) => image.size);
      if (sizes.join() !== expected.join()) problems.push(`${output.path} holds ${sizes.join(', ')}, not ${expected.join(', ')}`);
    }
  }
  for (const recorded of Object.keys(manifest.outputs ?? {})) {
    if (!list.some((output) => output.path === recorded)) problems.push(`${MANIFEST} lists ${recorded}, which this tool no longer writes`);
  }
  return problems;
}

async function main(argv) {
  let options;
  try {
    options = parseArgs(argv);
  } catch (error) {
    process.stderr.write(`app-icons: ${error.message}\n\n${USAGE}\n`);
    return 64;
  }
  if (options.help) {
    process.stdout.write(`${USAGE}\n`);
    return 0;
  }
  const root = path.resolve(options.root ?? path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..'));
  try {
    if (options.check) {
      const problems = await check(root);
      if (problems.length === 0) {
        process.stdout.write('app icons are current\n');
        return 0;
      }
      process.stdout.write(`${problems.join('\n')}\n`);
      return 1;
    }
    await generate(root, resolveChromium(options.chromium), process.stdout);
    return 0;
  } catch (error) {
    process.stderr.write(`app-icons: ${error.message}\n`);
    return 2;
  }
}

// Run as `node tools/app-icons` (the folder, through package.json's main) or as this file.
const self = fileURLToPath(import.meta.url);
const invoked = process.argv[1] ? path.resolve(process.argv[1]) : '';
if (invoked === self || invoked === path.dirname(self)) {
  process.exitCode = await main(process.argv.slice(2));
}
