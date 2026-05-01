#!/usr/bin/env node
'use strict';

const https    = require('https');
const fs       = require('fs');
const os       = require('os');
const path     = require('path');
const { execSync, spawnSync } = require('child_process');

// ── Config ────────────────────────────────────────────────────────────────────

const VERSION  = '0.1.0';
const REPO     = 'ryanjames1729/pixel-terminal';
const APP_NAME = 'Pixel Terminal.app';
const DMG_URL  = `https://github.com/${REPO}/releases/download/v${VERSION}/PixelTerminal.dmg`;

// ── Colors (true-color ANSI matching the app theme) ──────────────────────────

const c = {
  indigo: '\x1b[38;2;129;140;248m',
  mint:   '\x1b[38;2;110;231;183m',
  purple: '\x1b[38;2;167;139;250m',
  blue:   '\x1b[38;2;96;165;250m',
  yellow: '\x1b[38;2;251;191;36m',
  red:    '\x1b[38;2;248;113;113m',
  dim:    '\x1b[38;2;74;85;104m',
  reset:  '\x1b[0m',
  bold:   '\x1b[1m',
};

// ── Output helpers ────────────────────────────────────────────────────────────

const println = msg => process.stdout.write(msg + '\n');
const step    = msg => println(`${c.dim}  →${c.reset} ${msg}`);
const ok      = msg => println(`${c.mint}  ✓${c.reset} ${msg}`);
const warn    = msg => println(`${c.yellow}  ⚠${c.reset}  ${msg}`);
const fail    = msg => { println(`${c.red}  ✗${c.reset} ${msg}`); process.exit(1); };

// ── Banner ────────────────────────────────────────────────────────────────────

println('');
println(`${c.indigo}${c.bold}  ▸ pixel-terminal${c.reset} ${c.dim}v${VERSION} installer${c.reset}`);
println(`${c.dim}  ──────────────────────────────────────────────────${c.reset}`);
println('');

// ── Platform check ────────────────────────────────────────────────────────────

if (process.platform !== 'darwin') {
  fail('Pixel Terminal is a native macOS app and can only be installed on macOS.');
}

// Darwin major version: 22 = macOS 13 Ventura, 23 = Sonoma, 24 = Sequoia
const darwinMajor = parseInt(os.release().split('.')[0], 10);
if (darwinMajor < 22) {
  fail('Pixel Terminal requires macOS 13 Ventura or later.\n' +
       `     Your Darwin version: ${os.release()} — please upgrade macOS first.`);
}

// ── Resolve install location ──────────────────────────────────────────────────

const sysApps  = '/Applications';
const homeApps = path.join(os.homedir(), 'Applications');

// Prefer /Applications if writable without sudo, else fall back to ~/Applications
let destDir;
try {
  fs.accessSync(sysApps, fs.constants.W_OK);
  destDir = sysApps;
} catch {
  if (!fs.existsSync(homeApps)) fs.mkdirSync(homeApps, { recursive: true });
  destDir = homeApps;
}

const destApp = path.join(destDir, APP_NAME);

if (fs.existsSync(destApp)) {
  warn(`Existing installation found at ${destApp} — it will be replaced.`);
}

// ── Download DMG ──────────────────────────────────────────────────────────────

const tmpDmg = path.join(os.tmpdir(), `PixelTerminal-${VERSION}.dmg`);

step(`Downloading Pixel Terminal v${VERSION}…`);

function download(url, dest, hops = 0) {
  return new Promise((resolve, reject) => {
    if (hops > 8) return reject(new Error('Too many redirects'));

    const file = fs.createWriteStream(dest);
    const req  = https.get(url, { headers: { 'User-Agent': 'pixel-terminal-npm-installer' } }, res => {
      // Follow redirects (GitHub releases use several)
      if (res.statusCode === 301 || res.statusCode === 302 || res.statusCode === 307 || res.statusCode === 308) {
        file.close(() => {
          try { fs.unlinkSync(dest); } catch {}
          download(res.headers.location, dest, hops + 1).then(resolve).catch(reject);
        });
        return;
      }

      if (res.statusCode !== 200) {
        return reject(new Error(`HTTP ${res.statusCode} from ${url}`));
      }

      const total = parseInt(res.headers['content-length'] || '0', 10);
      let received = 0;

      res.on('data', chunk => {
        received += chunk.length;
        if (total > 0) {
          const pct  = Math.round(received / total * 100);
          const mb   = (received / 1024 / 1024).toFixed(1);
          const bar  = '█'.repeat(Math.floor(pct / 5)) + '░'.repeat(20 - Math.floor(pct / 5));
          process.stdout.write(`\r${c.dim}     [${bar}] ${pct}%  ${mb} MB${c.reset}`);
        }
      });

      res.pipe(file);
      file.on('finish', () => {
        file.close(() => {
          process.stdout.write('\n');
          resolve();
        });
      });
      file.on('error', reject);
    });

    req.on('error', reject);
  });
}

download(DMG_URL, tmpDmg)
  .then(() => {
    ok('Downloaded');

    // ── Mount DMG ────────────────────────────────────────────────────────────
    step('Mounting disk image…');
    const mountPoint = '/Volumes/Pixel Terminal';

    // Detach any stale mount from a previous run
    execSync(`hdiutil detach "${mountPoint}" -quiet 2>/dev/null; true`, { stdio: 'ignore', shell: true });

    const mount = spawnSync('hdiutil', ['attach', tmpDmg, '-nobrowse', '-quiet']);
    if (mount.status !== 0) {
      fail('Could not mount DMG:\n' + (mount.stderr?.toString() ?? ''));
    }
    if (!fs.existsSync(mountPoint)) {
      fail('Mounted volume not found at ' + mountPoint);
    }
    ok(`Mounted at ${mountPoint}`);

    // ── Copy .app ────────────────────────────────────────────────────────────
    const srcApp = path.join(mountPoint, APP_NAME);
    if (!fs.existsSync(srcApp)) {
      execSync(`hdiutil detach "${mountPoint}" -quiet 2>/dev/null; true`, { stdio: 'ignore', shell: true });
      fail(`${APP_NAME} not found in disk image.`);
    }

    step(`Installing to ${destDir}…`);
    try {
      if (fs.existsSync(destApp)) execSync(`rm -rf "${destApp}"`, { stdio: 'ignore' });
      execSync(`cp -r "${srcApp}" "${destDir}/"`, { stdio: 'ignore' });
    } catch (e) {
      execSync(`hdiutil detach "${mountPoint}" -quiet 2>/dev/null; true`, { stdio: 'ignore', shell: true });
      fail(`Copy failed — try: sudo npx pixel-terminal\n     ${e.message}`);
    }
    ok(`Installed → ${destApp}`);

    // ── Unmount ───────────────────────────────────────────────────────────────
    execSync(`hdiutil detach "${mountPoint}" -quiet 2>/dev/null; true`, { stdio: 'ignore', shell: true });

    // ── Remove quarantine flag ────────────────────────────────────────────────
    // Without this macOS Gatekeeper blocks the unsigned app on first launch.
    try {
      execSync(`xattr -dr com.apple.quarantine "${destApp}"`, { stdio: 'ignore' });
    } catch { /* not fatal */ }

    // ── Clean up temp DMG ─────────────────────────────────────────────────────
    try { fs.unlinkSync(tmpDmg); } catch {}

    // ── Launch ───────────────────────────────────────────────────────────────
    step('Launching Pixel Terminal…');
    spawnSync('open', [destApp], { stdio: 'ignore' });

    // ── Done ─────────────────────────────────────────────────────────────────
    println('');
    println(`${c.dim}  ──────────────────────────────────────────────────${c.reset}`);
    println(`  ${c.mint}${c.bold}Pixel Terminal is installed!${c.reset}`);
    println('');
    println(`  ${c.dim}Location:${c.reset}  ${destApp}`);
    println(`  ${c.dim}Tip:${c.reset}       Drag it from ${destDir} to your Dock`);
    println('');
    println(`  ${c.dim}Keyboard shortcuts:${c.reset}`);
    println(`  ${c.dim}  ⌘T${c.reset} new session  ${c.dim}⌘⇧C${c.reset} ${c.purple}claude code${c.reset}  ${c.dim}⌘⇧N${c.reset} ${c.blue}network cmds${c.reset}`);
    println(`${c.dim}  ──────────────────────────────────────────────────${c.reset}`);
    println('');
  })
  .catch(err => {
    try { fs.unlinkSync(tmpDmg); } catch {}
    fail(`Installation failed: ${err.message}`);
  });
