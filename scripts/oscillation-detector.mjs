#!/usr/bin/env node
import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync, realpathSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { resolve } from 'node:path';

const input = JSON.parse(readFileSync(process.stdin.fd, 'utf8'));
const filePath = input?.tool_input?.file_path || input?.tool_input?.path || '';
if (!filePath) process.exit(0);

const rawRoot = execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
const root = realpathSync(rawRoot);
const stateDir = resolve(root, '.robro');
const stateFile = resolve(stateDir, '.oscillation-state.json');

if (!existsSync(stateDir)) mkdirSync(stateDir, { recursive: true });

let state = {};
if (existsSync(stateFile)) {
  try { state = JSON.parse(readFileSync(stateFile, 'utf8')); } catch { state = {}; }
}

// Compute relative path, handling symlinks (e.g., /var vs /private/var on macOS)
// Try to resolve the filePath to its real path by resolving the deepest existing ancestor
let normalizedFilePath = filePath;
try {
  // Walk up from filePath to find an existing ancestor we can resolve
  let testPath = filePath;
  let suffix = '';
  while (testPath && testPath !== '/') {
    if (existsSync(testPath)) {
      normalizedFilePath = realpathSync(testPath) + suffix;
      break;
    }
    const parent = resolve(testPath, '..');
    suffix = testPath.slice(parent.length) + suffix;
    testPath = parent;
  }
} catch { /* keep original */ }

let rel;
if (normalizedFilePath.startsWith(root)) {
  rel = normalizedFilePath.slice(root.length + 1);
} else if (normalizedFilePath.startsWith(rawRoot)) {
  rel = normalizedFilePath.slice(rawRoot.length + 1);
} else {
  rel = filePath;
}
state[rel] = (state[rel] || 0) + 1;

// Atomic write
const tmp = stateFile + '.tmp.' + process.pid;
writeFileSync(tmp, JSON.stringify(state));
renameSync(tmp, stateFile);

// Read threshold from project config, fallback to default
let threshold = 3;
try {
  const configPath = resolve(root, '.robro', 'config.json');
  if (existsSync(configPath)) {
    const config = JSON.parse(readFileSync(configPath, 'utf8'));
    threshold = config?.thresholds?.oscillation_cycle_threshold ?? 3;
  }
} catch { /* use default */ }

const oscillating = Object.entries(state).filter(([, c]) => c >= threshold);

if (oscillating.length > 0) {
  const files = oscillating.map(([f, c]) => `${f} (${c}x)`).join(', ');
  console.log(JSON.stringify({
    continue: true,
    hookSpecificOutput: {
      hookEventName: 'PostToolUse',
      additionalContext: `<oscillation-warning>\nOSCILLATION DETECTED: ${files}\nConsider whether the current approach is working or needs a lateral shift.\n</oscillation-warning>`
    }
  }));
}
