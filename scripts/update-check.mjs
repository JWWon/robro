#!/usr/bin/env node
import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync } from 'node:fs';
import { resolve } from 'node:path';
import { homedir } from 'node:os';

const CACHE_TTL = 24 * 60 * 60 * 1000;
const REMOTE_URL = 'https://raw.githubusercontent.com/JWWon/robro/main/.claude-plugin/plugin.json';
const cacheDir = resolve(homedir(), '.robro');
const cacheFile = resolve(cacheDir, '.update-cache.json');

let localVersion;
try {
  const pluginRoot = process.env.CLAUDE_PLUGIN_ROOT || resolve(new URL('.', import.meta.url).pathname, '..');
  localVersion = JSON.parse(readFileSync(resolve(pluginRoot, '.claude-plugin', 'plugin.json'), 'utf8')).version;
} catch { process.exit(0); }

if (!existsSync(cacheDir)) mkdirSync(cacheDir, { recursive: true });

if (existsSync(cacheFile)) {
  try {
    const cache = JSON.parse(readFileSync(cacheFile, 'utf8'));
    if (Date.now() - cache.checked_at < CACHE_TTL) {
      if (cache.remote_version && cache.remote_version !== localVersion) {
        console.log(`Update available: robro ${cache.remote_version} (current: ${localVersion}). Run plugin update to upgrade.`);
      }
      process.exit(0);
    }
  } catch { /* stale, re-fetch */ }
}

try {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2000);
  const resp = await fetch(REMOTE_URL, { signal: controller.signal });
  clearTimeout(timeout);
  if (resp.ok) {
    const remote = JSON.parse(await resp.text());
    const tmp = cacheFile + '.tmp.' + process.pid;
    writeFileSync(tmp, JSON.stringify({ checked_at: Date.now(), remote_version: remote.version }));
    renameSync(tmp, cacheFile);
    if (remote.version !== localVersion) {
      console.log(`Update available: robro ${remote.version} (current: ${localVersion}). Run plugin update to upgrade.`);
    }
  }
} catch { /* network error — skip silently */ }
