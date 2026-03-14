#!/usr/bin/env node
import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync, readdirSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { resolve, join } from 'node:path';
import { homedir } from 'node:os';

// Read stdin
let input;
try {
  input = JSON.parse(readFileSync(process.stdin.fd, 'utf8'));
} catch { process.exit(0); }

const prompt = (input?.prompt || '').toLowerCase();
if (!prompt) process.exit(0);

const root = execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
const robroDir = resolve(root, '.robro');
const indexFile = resolve(robroDir, '.skill-index.json');
const injectedFile = resolve(robroDir, '.injected-skills.json');

// Read config for injection cap
let cap = 5;
try {
  const configPath = resolve(robroDir, 'config.json');
  if (existsSync(configPath)) {
    const config = JSON.parse(readFileSync(configPath, 'utf8'));
    cap = config?.thresholds?.skill_injection_cap ?? 5;
  }
} catch { /* default */ }

// --- Index Builder ---
function parseJsonFrontmatter(content) {
  const match = content.match(/^---\s*\n(\{[\s\S]*?\})\s*\n---/);
  if (!match) return null;
  try { return JSON.parse(match[1]); } catch { return null; }
}

function buildIndex() {
  const skills = [];
  const dirs = [
    { path: resolve(robroDir, 'skills'), scope: 'project' },
    { path: resolve(homedir(), '.robro', 'skills'), scope: 'user' }
  ];

  for (const { path: dir, scope } of dirs) {
    if (!existsSync(dir)) continue;
    for (const file of readdirSync(dir)) {
      if (!file.endsWith('.md')) continue;
      const fullPath = join(dir, file);
      try {
        const content = readFileSync(fullPath, 'utf8');
        const fm = parseJsonFrontmatter(content);
        if (fm && fm.name && fm.triggers && Array.isArray(fm.triggers)) {
          skills.push({
            path: fullPath,
            name: fm.name,
            triggers: fm.triggers.map(t => t.toLowerCase()),
            description: fm.description || '',
            scope
          });
        }
      } catch { /* skip unreadable files */ }
    }
  }

  const index = { built_at: new Date().toISOString(), skills };
  if (!existsSync(robroDir)) mkdirSync(robroDir, { recursive: true });
  const tmp = indexFile + '.tmp.' + process.pid;
  writeFileSync(tmp, JSON.stringify(index, null, 2));
  renameSync(tmp, indexFile);
  return index;
}

// --- Load or rebuild index ---
let index;
if (existsSync(indexFile)) {
  try {
    index = JSON.parse(readFileSync(indexFile, 'utf8'));
  } catch { index = buildIndex(); }
} else {
  index = buildIndex();
}

if (!index.skills || index.skills.length === 0) process.exit(0);

// --- Sanitize prompt ---
function sanitize(text) {
  return text
    .replace(/<[^>]*>/g, '')           // strip XML tags
    .replace(/https?:\/\/\S+/g, '')    // strip URLs
    .replace(/\/[\w./]+\.\w+/g, '')    // strip file paths
    .replace(/```[\s\S]*?```/g, '')    // strip code blocks
    .toLowerCase();
}

const cleaned = sanitize(prompt);

// --- Match triggers ---
const matched = index.skills.filter(skill =>
  skill.triggers.some(trigger => cleaned.includes(trigger))
);

if (matched.length === 0) process.exit(0);

// --- Dedup against already-injected ---
let alreadyInjected = [];
if (existsSync(injectedFile)) {
  try { alreadyInjected = JSON.parse(readFileSync(injectedFile, 'utf8')); } catch { alreadyInjected = []; }
}

const newMatches = matched.filter(s => !alreadyInjected.includes(s.name));
if (newMatches.length === 0) process.exit(0);

// Project-scoped first, then user-scoped; cap total
const sorted = [
  ...newMatches.filter(s => s.scope === 'project'),
  ...newMatches.filter(s => s.scope === 'user')
];
const remaining = cap - alreadyInjected.length;
const toInject = sorted.slice(0, Math.max(0, remaining));

if (toInject.length === 0) process.exit(0);

// --- Read and inject skill content ---
const injections = toInject.map(skill => {
  const content = readFileSync(skill.path, 'utf8');
  // Strip frontmatter
  const body = content.replace(/^---\s*\n\{[\s\S]*?\}\s*\n---\s*\n?/, '');
  return `<project-skill name="${skill.name}">\n${body.trim()}\n</project-skill>`;
});

// --- Update injected tracking ---
const updated = [...alreadyInjected, ...toInject.map(s => s.name)];
const tmp2 = injectedFile + '.tmp.' + process.pid;
writeFileSync(tmp2, JSON.stringify(updated));
renameSync(tmp2, injectedFile);

// --- Output ---
console.log(JSON.stringify({
  continue: true,
  hookSpecificOutput: {
    hookEventName: 'UserPromptSubmit',
    additionalContext: injections.join('\n\n')
  }
}));
