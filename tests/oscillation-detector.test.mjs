#!/usr/bin/env node
/**
 * Tests for oscillation-detector.mjs
 *
 * Tests the hook by simulating stdin input and checking:
 * 1. State file tracking (counts edits per file)
 * 2. Warning output when threshold is reached
 * 3. Configurable threshold via .robro/config.json
 * 4. No output below threshold
 * 5. Graceful handling of missing file_path
 */
import { execSync } from 'node:child_process';
import { writeFileSync, readFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, '..');
const scriptPath = resolve(projectRoot, 'scripts', 'oscillation-detector.mjs');

let tmpDir;
let passed = 0;
let failed = 0;

function setup() {
  tmpDir = execSync('mktemp -d', { encoding: 'utf8' }).trim();
  execSync('git init', { cwd: tmpDir, stdio: 'pipe' });
  mkdirSync(resolve(tmpDir, '.robro'), { recursive: true });
}

function teardown() {
  if (tmpDir && existsSync(tmpDir)) {
    rmSync(tmpDir, { recursive: true, force: true });
  }
}

function runScript(input) {
  try {
    const result = execSync(
      `echo '${JSON.stringify(input).replace(/'/g, "\\'")}' | node ${scriptPath}`,
      { encoding: 'utf8', cwd: tmpDir, stdio: ['pipe', 'pipe', 'pipe'], timeout: 5000 }
    );
    return result.trim();
  } catch (e) {
    return (e.stdout || '').trim();
  }
}

function tryParseJSON(str) {
  try { return JSON.parse(str); } catch { return null; }
}

function assert(condition, message) {
  if (condition) { passed++; console.log(`  PASS: ${message}`); }
  else { failed++; console.log(`  FAIL: ${message}`); }
}

// --- Tests ---

console.log('Test 1: No output when file_path is empty');
setup();
try {
  const output = runScript({ tool_input: {} });
  assert(output === '', 'Should produce no output for empty input');
} finally { teardown(); }

console.log('Test 2: State file is created and counts edits');
setup();
try {
  const input = { tool_input: { file_path: resolve(tmpDir, 'src/foo.ts') } };
  runScript(input);
  const stateFile = resolve(tmpDir, '.robro', '.oscillation-state.json');
  const exists = existsSync(stateFile);
  assert(exists, 'State file should exist after first edit');
  if (exists) {
    const state = tryParseJSON(readFileSync(stateFile, 'utf8'));
    assert(state && state['src/foo.ts'] === 1, 'Count should be 1 after first edit');
    runScript(input);
    const state2 = tryParseJSON(readFileSync(stateFile, 'utf8'));
    assert(state2 && state2['src/foo.ts'] === 2, 'Count should be 2 after second edit');
  } else {
    assert(false, 'Count should be 1 (skipped)');
    assert(false, 'Count should be 2 (skipped)');
  }
} finally { teardown(); }

console.log('Test 3: No warning below threshold (default 3)');
setup();
try {
  const input = { tool_input: { file_path: resolve(tmpDir, 'src/bar.ts') } };
  assert(runScript(input) === '', 'No warning at count 1');
  assert(runScript(input) === '', 'No warning at count 2');
} finally { teardown(); }

console.log('Test 4: Warning emitted at threshold (default 3)');
setup();
try {
  const input = { tool_input: { file_path: resolve(tmpDir, 'src/baz.ts') } };
  runScript(input); // 1
  runScript(input); // 2
  const out3 = runScript(input); // 3
  assert(out3.length > 0, 'Should produce output at threshold');
  const parsed = tryParseJSON(out3);
  assert(parsed !== null, 'Output should be valid JSON');
  if (parsed) {
    assert(parsed.continue === true, 'Should have continue: true');
    assert(
      parsed?.hookSpecificOutput?.additionalContext?.includes('OSCILLATION DETECTED'),
      'Should contain oscillation warning'
    );
    assert(
      parsed?.hookSpecificOutput?.additionalContext?.includes('src/baz.ts (3x)'),
      'Should include file name and count'
    );
  } else {
    assert(false, 'continue: true (skipped)');
    assert(false, 'oscillation warning (skipped)');
    assert(false, 'file name and count (skipped)');
  }
} finally { teardown(); }

console.log('Test 5: Configurable threshold via .robro/config.json');
setup();
try {
  writeFileSync(
    resolve(tmpDir, '.robro', 'config.json'),
    JSON.stringify({ thresholds: { oscillation_cycle_threshold: 2 } })
  );
  const input = { tool_input: { file_path: resolve(tmpDir, 'src/qux.ts') } };
  runScript(input); // 1
  const out2 = runScript(input); // 2
  assert(out2.length > 0, 'Should produce output at custom threshold 2');
  const parsed = tryParseJSON(out2);
  if (parsed) {
    assert(
      parsed?.hookSpecificOutput?.additionalContext?.includes('OSCILLATION DETECTED'),
      'Should contain oscillation warning with custom threshold'
    );
  } else {
    assert(false, 'oscillation warning with custom threshold (skipped - invalid JSON)');
  }
} finally { teardown(); }

console.log('Test 6: Supports tool_input.path as fallback');
setup();
try {
  const input = { tool_input: { path: resolve(tmpDir, 'src/alt.ts') } };
  runScript(input);
  const stateFile = resolve(tmpDir, '.robro', '.oscillation-state.json');
  if (existsSync(stateFile)) {
    const state = tryParseJSON(readFileSync(stateFile, 'utf8'));
    assert(state && state['src/alt.ts'] === 1, 'Should track via path field');
  } else {
    assert(false, 'Should track via path field (no state file)');
  }
} finally { teardown(); }

// --- Summary ---
console.log(`\nResults: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
