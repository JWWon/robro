#!/usr/bin/env node
/**
 * Tests for skill-injector.mjs
 *
 * Tests the UserPromptSubmit hook by simulating stdin input and checking:
 * 1. No output when prompt is empty
 * 2. Index is built from .robro/skills/*.md files
 * 3. Matching triggers produce project-skill tag output
 * 4. Already-injected skills are not re-injected
 * 5. Injection cap is respected
 * 6. Project-scoped skills are prioritized over user-scoped
 * 7. Prompt sanitization strips XML tags, URLs, code blocks, file paths
 * 8. No output when no skills match
 * 9. JSON frontmatter parsing works correctly
 */
import { execSync } from 'node:child_process';
import { writeFileSync, readFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, '..');
const scriptPath = resolve(projectRoot, 'scripts', 'skill-injector.mjs');

let tmpDir;
let passed = 0;
let failed = 0;

function setup() {
  tmpDir = execSync('mktemp -d', { encoding: 'utf8' }).trim();
  execSync('git init', { cwd: tmpDir, stdio: 'pipe' });
  mkdirSync(resolve(tmpDir, '.robro', 'skills'), { recursive: true });
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

function writeSkill(name, triggers, description, body) {
  const fm = JSON.stringify({ name, triggers, description });
  const content = `---\n${fm}\n---\n${body}`;
  writeFileSync(resolve(tmpDir, '.robro', 'skills', `${name}.md`), content);
}

// --- Tests ---

console.log('Test 1: No output when prompt is empty');
setup();
try {
  const output = runScript({ prompt: '' });
  assert(output === '', 'Should produce no output for empty prompt');
} finally { teardown(); }

console.log('Test 2: No output when no skills directory exists');
setup();
try {
  rmSync(resolve(tmpDir, '.robro', 'skills'), { recursive: true, force: true });
  const output = runScript({ prompt: 'some text' });
  assert(output === '', 'Should produce no output when no skills dir');
} finally { teardown(); }

console.log('Test 3: Matching trigger produces project-skill tag output');
setup();
try {
  writeSkill('deploy-helper', ['deploy', 'deployment'], 'Helps with deploys', 'Deploy instructions here.');
  const output = runScript({ prompt: 'I need to deploy my app' });
  assert(output.length > 0, 'Should produce output when trigger matches');
  const parsed = tryParseJSON(output);
  assert(parsed !== null, 'Output should be valid JSON');
  if (parsed) {
    assert(parsed.continue === true, 'Should have continue: true');
    const ctx = parsed?.hookSpecificOutput?.additionalContext || '';
    assert(ctx.includes('<project-skill name="deploy-helper">'), 'Should contain project-skill tag');
    assert(ctx.includes('Deploy instructions here.'), 'Should contain skill body');
    assert(!ctx.includes('---'), 'Should strip frontmatter from body');
  }
} finally { teardown(); }

console.log('Test 4: No output when no triggers match');
setup();
try {
  writeSkill('deploy-helper', ['deploy'], 'Helps with deploys', 'Body');
  const output = runScript({ prompt: 'I want to test something' });
  assert(output === '', 'Should produce no output when no triggers match');
} finally { teardown(); }

console.log('Test 5: Already-injected skills are not re-injected');
setup();
try {
  writeSkill('my-skill', ['magic word'], 'Desc', 'Skill body');
  // First injection
  const out1 = runScript({ prompt: 'magic word' });
  assert(out1.length > 0, 'First injection should produce output');
  // Second injection with same prompt
  const out2 = runScript({ prompt: 'magic word again' });
  assert(out2 === '', 'Should not re-inject already-injected skill');
  // Verify injected tracking file exists
  const injectedFile = resolve(tmpDir, '.robro', '.injected-skills.json');
  const injectedExists = existsSync(injectedFile);
  assert(injectedExists, 'Injected tracking file should exist');
  if (injectedExists) {
    const injected = tryParseJSON(readFileSync(injectedFile, 'utf8'));
    assert(Array.isArray(injected) && injected.includes('my-skill'), 'Should track injected skill name');
  } else {
    assert(false, 'Should track injected skill name (skipped - no file)');
  }
} finally { teardown(); }

console.log('Test 6: Injection cap is respected');
setup();
try {
  // Set cap to 2
  writeFileSync(
    resolve(tmpDir, '.robro', 'config.json'),
    JSON.stringify({ thresholds: { skill_injection_cap: 2 } })
  );
  writeSkill('skill-a', ['alpha'], 'A', 'Body A');
  writeSkill('skill-b', ['beta'], 'B', 'Body B');
  writeSkill('skill-c', ['gamma'], 'C', 'Body C');
  // Match all three at once
  const output = runScript({ prompt: 'alpha beta gamma' });
  const parsed = tryParseJSON(output);
  if (parsed) {
    const ctx = parsed?.hookSpecificOutput?.additionalContext || '';
    const matches = ctx.match(/<project-skill/g) || [];
    assert(matches.length === 2, `Should inject at most 2 skills (got ${matches.length})`);
  } else {
    assert(false, 'Should inject at most 2 skills (no valid JSON output)');
  }
} finally { teardown(); }

console.log('Test 7: Index file is created as cache');
setup();
try {
  writeSkill('cached-skill', ['cache test'], 'Desc', 'Body');
  runScript({ prompt: 'cache test' });
  const indexFile = resolve(tmpDir, '.robro', '.skill-index.json');
  const indexExists = existsSync(indexFile);
  assert(indexExists, 'Index file should be created');
  if (indexExists) {
    const index = tryParseJSON(readFileSync(indexFile, 'utf8'));
    assert(index !== null && Array.isArray(index.skills), 'Index should have skills array');
    if (index && index.skills) {
      assert(index.skills.length === 1, 'Index should have 1 skill');
      assert(index.skills[0].name === 'cached-skill', 'Skill name should match');
    }
  } else {
    assert(false, 'Index should have skills array (skipped)');
    assert(false, 'Index should have 1 skill (skipped)');
    assert(false, 'Skill name should match (skipped)');
  }
} finally { teardown(); }

console.log('Test 8: Prompt sanitization strips XML tags');
setup();
try {
  writeSkill('sanitize-test', ['hidden keyword'], 'Desc', 'Body');
  // Keyword is inside an XML tag attribute - should still match after stripping tags
  const output = runScript({ prompt: '<tag>hidden keyword</tag>' });
  // After sanitization, XML tags are stripped so "hidden keyword" remains
  assert(output.length > 0, 'Should match trigger after stripping XML tags from surrounding text');
} finally { teardown(); }

console.log('Test 9: Skills without proper frontmatter are skipped');
setup();
try {
  // Write a skill without valid JSON frontmatter
  writeFileSync(
    resolve(tmpDir, '.robro', 'skills', 'bad-skill.md'),
    '---\nnot json\n---\nBody content'
  );
  writeSkill('good-skill', ['good trigger'], 'Desc', 'Good body');
  const output = runScript({ prompt: 'good trigger' });
  const parsed = tryParseJSON(output);
  if (parsed) {
    const ctx = parsed?.hookSpecificOutput?.additionalContext || '';
    assert(!ctx.includes('bad-skill'), 'Should skip skills with invalid frontmatter');
    assert(ctx.includes('good-skill'), 'Should still inject valid skills');
  } else {
    assert(false, 'Should produce valid output (skipped)');
  }
} finally { teardown(); }

// --- User-scoped skill tests ---
import { homedir } from 'node:os';

const userSkillsDir = resolve(homedir(), '.robro', 'skills');
let userSkillsDirExisted;

function setupUserSkills() {
  userSkillsDirExisted = existsSync(userSkillsDir);
  if (!userSkillsDirExisted) {
    mkdirSync(userSkillsDir, { recursive: true });
  }
}

function teardownUserSkills() {
  // Only remove what we created
  const testSkill = resolve(userSkillsDir, 'user-test-skill.md');
  if (existsSync(testSkill)) rmSync(testSkill);
  // Clean up directory only if we created it
  if (!userSkillsDirExisted) {
    try {
      // Remove skills dir, then .robro if empty
      const parentDir = resolve(homedir(), '.robro');
      rmSync(userSkillsDir, { recursive: true, force: true });
      // Only remove parent if it's empty
      if (existsSync(parentDir) && readdirSync(parentDir).length === 0) {
        rmSync(parentDir, { recursive: true, force: true });
      }
    } catch { /* best effort */ }
  }
}

function writeUserSkill(name, triggers, description, body) {
  const fm = JSON.stringify({ name, triggers, description });
  const content = `---\n${fm}\n---\n${body}`;
  writeFileSync(resolve(userSkillsDir, `${name}.md`), content);
}

console.log('Test 10: User-scoped skills from ~/.robro/skills/ are indexed');
setup();
setupUserSkills();
try {
  writeUserSkill('user-test-skill', ['user magic'], 'A user-scoped skill', 'User skill body here.');
  const output = runScript({ prompt: 'user magic' });
  assert(output.length > 0, 'Should produce output for user-scoped skill trigger');
  const parsed = tryParseJSON(output);
  if (parsed) {
    const ctx = parsed?.hookSpecificOutput?.additionalContext || '';
    assert(ctx.includes('<project-skill name="user-test-skill">'), 'Should contain user skill in output');
    assert(ctx.includes('User skill body here.'), 'Should contain user skill body');
  } else {
    assert(false, 'Output should be valid JSON for user skill');
    assert(false, 'Should contain user skill body (skipped)');
  }
  // Verify the index has scope: "user"
  const indexFile2 = resolve(tmpDir, '.robro', '.skill-index.json');
  if (existsSync(indexFile2)) {
    const index2 = tryParseJSON(readFileSync(indexFile2, 'utf8'));
    const userEntry = index2?.skills?.find(s => s.name === 'user-test-skill');
    assert(userEntry !== undefined, 'Index should contain user-scoped skill');
    assert(userEntry?.scope === 'user', 'User skill should have scope: "user"');
  } else {
    assert(false, 'Index should contain user-scoped skill (no index file)');
    assert(false, 'User skill should have scope: "user" (no index file)');
  }
} finally { teardownUserSkills(); teardown(); }

console.log('Test 11: Project-scoped skills are prioritized over user-scoped');
setup();
setupUserSkills();
try {
  // Set cap to 1 so only one skill can be injected
  writeFileSync(
    resolve(tmpDir, '.robro', 'config.json'),
    JSON.stringify({ thresholds: { skill_injection_cap: 1 } })
  );
  // Both skills trigger on the same word
  writeSkill('project-skill', ['priority test'], 'Project skill', 'Project body');
  writeUserSkill('user-test-skill', ['priority test'], 'User skill', 'User body');
  const output = runScript({ prompt: 'priority test' });
  const parsed = tryParseJSON(output);
  if (parsed) {
    const ctx = parsed?.hookSpecificOutput?.additionalContext || '';
    assert(ctx.includes('project-skill'), 'Project-scoped skill should be injected when cap is 1');
    assert(!ctx.includes('user-test-skill'), 'User-scoped skill should be excluded when cap reached');
  } else {
    assert(false, 'Project skill should be prioritized (no valid JSON)');
    assert(false, 'User skill should be excluded (no valid JSON)');
  }
} finally { teardownUserSkills(); teardown(); }

// --- Summary ---
console.log(`\nResults: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
