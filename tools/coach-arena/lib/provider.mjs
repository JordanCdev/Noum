// Provider abstraction for coach generation + judging.
//
//   anthropic : POST api.anthropic.com/v1/messages — matches the app exactly
//               (x-api-key, anthropic-version 2023-06-01, model claude-sonnet-4-6).
//               Requires ANTHROPIC_API_KEY. This is production parity.
//   cli       : shells out to `claude -p` (works in a normally-authenticated
//               terminal; not from a nested child session).
//   replay    : reads pre-captured replies/verdicts from a captures dir. Pure
//               offline; used for deterministic-check runs, CI, and reproducing
//               a report without spending tokens.

import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { execFile } from 'node:child_process';

export const COACH_MODEL = process.env.ARENA_MODEL || 'claude-sonnet-4-6';
export const JUDGE_MODEL = process.env.ARENA_JUDGE_MODEL || 'claude-sonnet-4-6';
const ANTHROPIC_VERSION = '2023-06-01';

async function anthropicMessages({ system, messages, model, maxTokens = 1024 }) {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error('anthropic provider: ANTHROPIC_API_KEY not set');
  const started = Date.now();
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': key,
      'anthropic-version': ANTHROPIC_VERSION,
    },
    body: JSON.stringify({ model, max_tokens: maxTokens, system, messages }),
  });
  const latencyMs = Date.now() - started;
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`anthropic ${res.status}: ${body.slice(0, 300)}`);
  }
  const data = await res.json();
  const text = (data.content || []).filter((c) => c.type === 'text').map((c) => c.text).join('');
  return { text, usage: data.usage || null, model, provider: 'anthropic', latencyMs, stopReason: data.stop_reason };
}

function cliMessages({ system, messages, model, maxTokens = 1024 }) {
  const userText = messages.map((m) => `${m.role.toUpperCase()}: ${m.content}`).join('\n\n');
  return new Promise((resolve, reject) => {
    const started = Date.now();
    const child = execFile(
      'claude',
      ['-p', '--model', model, '--append-system-prompt', system, '--max-turns', '1'],
      { maxBuffer: 8 * 1024 * 1024 },
      (err, stdout) => {
        const latencyMs = Date.now() - started;
        if (err) return reject(new Error('cli provider: ' + err.message));
        resolve({ text: stdout.trim(), usage: null, model, provider: 'cli', latencyMs, stopReason: 'cli' });
      },
    );
    child.stdin.write(userText);
    child.stdin.end();
  });
}

function makeReplay(capturesDir, { kind }) {
  // kind: 'reply' -> captures/<id>.reply.txt ; 'judge' -> captures/<id>.judge.json
  return async ({ id }) => {
    const ext = kind === 'judge' ? 'judge.json' : 'reply.txt';
    const path = join(capturesDir, `${id}.${ext}`);
    if (!existsSync(path)) {
      return { text: '', usage: null, model: 'replay', provider: 'replay', latencyMs: 0, missing: true };
    }
    const meta = readMeta(capturesDir, id);
    return { text: readFileSync(path, 'utf8'), usage: meta?.usage || null, model: meta?.model || 'replay', provider: 'replay', latencyMs: meta?.latencyMs || 0, stopReason: 'replay' };
  };
}
function readMeta(capturesDir, id) {
  const p = join(capturesDir, `${id}.meta.json`);
  return existsSync(p) ? JSON.parse(readFileSync(p, 'utf8')) : null;
}

// Returns { generate(fixtureRef, {system, messages, maxTokens}), judge(...) }.
export function makeProvider(name, { capturesDir } = {}) {
  if (name === 'anthropic') {
    return {
      name,
      generate: (ref, req) => anthropicMessages({ ...req, model: req.model || COACH_MODEL }),
      judge: (ref, req) => anthropicMessages({ ...req, model: req.model || JUDGE_MODEL }),
    };
  }
  if (name === 'cli') {
    return {
      name,
      generate: (ref, req) => cliMessages({ ...req, model: req.model || COACH_MODEL }),
      judge: (ref, req) => cliMessages({ ...req, model: req.model || JUDGE_MODEL }),
    };
  }
  if (name === 'replay') {
    if (!capturesDir) throw new Error('replay provider requires capturesDir');
    return {
      name,
      generate: makeReplay(capturesDir, { kind: 'reply' }),
      judge: makeReplay(capturesDir, { kind: 'judge' }),
    };
  }
  throw new Error('unknown provider: ' + name);
}
