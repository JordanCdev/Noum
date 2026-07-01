// Trace provenance: git commit/branch/dirty, tool versions, prompt source
// hashes. Every run records this so a report can be tied to an exact state of
// the coach.

import { execSync } from 'node:child_process';
import { REPO_ROOT } from './extractPrompt.mjs';

function git(args) {
  try {
    return execSync(`git ${args}`, { cwd: REPO_ROOT, encoding: 'utf8' }).trim();
  } catch {
    return null;
  }
}

export function gitTrace() {
  const dirty = git('status --porcelain');
  return {
    commit: git('rev-parse HEAD'),
    shortCommit: git('rev-parse --short HEAD'),
    branch: git('rev-parse --abbrev-ref HEAD'),
    dirty: dirty ? dirty.split('\n').length : 0,
  };
}

export function toolVersions(extra = {}) {
  return {
    node: process.version,
    arena: '1.0.0',
    ...extra,
  };
}
