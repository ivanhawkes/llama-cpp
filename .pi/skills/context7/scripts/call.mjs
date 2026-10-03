#!/usr/bin/env node
// call.mjs — minimal MCP stdio client for @upstash/context7-mcp (no npm deps).
//
// Usage:
//   node call.mjs <tool-name> '<json-arguments>' [--max-chars N] [--verbose]
//
// Tools:
//   resolve-library-id  {"query": "<topic>", "libraryName": "<package name>"}
//   query-docs          {"libraryId": "/org/project", "query": "<one narrow topic>"}
//
// Exit codes: 0 ok · 1 tool/JSON-RPC error · 2 timeout · 3 spawn/protocol failure
// Env: CONTEXT7_TIMEOUT_MS (default 120000), CONTEXT7_MAX_CHARS (default 12000),
//      CONTEXT7_MCP_BIN (override path to the server entry point)

import { spawn } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const argv = process.argv.slice(2);
const flags = { maxChars: Number(process.env.CONTEXT7_MAX_CHARS ?? 12_000), verbose: false };
const positional = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--max-chars') flags.maxChars = Number(argv[++i]);
  else if (argv[i] === '--verbose') flags.verbose = true;
  else positional.push(argv[i]);
}
const [toolName, rawArgs] = positional;
if (!toolName || !rawArgs) {
  console.error("usage: node call.mjs <tool-name> '<json-arguments>' [--max-chars N] [--verbose]");
  process.exit(3);
}
let toolArgs;
try {
  toolArgs = JSON.parse(rawArgs);
} catch (e) {
  console.error(`invalid JSON arguments: ${e.message}`);
  process.exit(3);
}

const TIMEOUT_MS = Number(process.env.CONTEXT7_TIMEOUT_MS ?? 120_000);

function findPackageDir() {
  let dir = path.dirname(fileURLToPath(import.meta.url));
  for (let i = 0; i < 8; i++) {
    // plain node_modules, plus the NPM_CONFIG_PREFIX layout (.pi/npm/node_modules)
    for (const base of [path.join(dir, 'node_modules'), path.join(dir, 'npm', 'node_modules')]) {
      const candidate = path.join(base, '@upstash', 'context7-mcp');
      if (existsSync(path.join(candidate, 'package.json'))) return candidate;
    }
    dir = path.dirname(dir);
  }
  console.error('error: cannot locate @upstash/context7-mcp — run `npm install @upstash/context7-mcp` in .pi/npm');
  process.exit(3);
}

let binPath;
if (process.env.CONTEXT7_MCP_BIN) {
  binPath = process.env.CONTEXT7_MCP_BIN;
} else {
  const pkgDir = findPackageDir();
  const pkg = JSON.parse(readFileSync(path.join(pkgDir, 'package.json'), 'utf8'));
  const bin = typeof pkg.bin === 'string' ? pkg.bin : pkg.bin[Object.keys(pkg.bin)[0]];
  binPath = path.join(pkgDir, bin);
}

const child = spawn(process.execPath, [binPath], { stdio: ['pipe', 'pipe', 'pipe'] });
let stderrBuf = '';
child.stderr.on('data', (d) => {
  stderrBuf += d;
  if (flags.verbose) process.stderr.write(d);
});

function fail(code, message) {
  if (stderrBuf.trim()) process.stderr.write(`\n[server stderr]\n${stderrBuf.trim()}\n`);
  console.error(message);
  child.kill('SIGKILL');
  process.exit(code);
}

let stdoutBuf = '';
const pending = new Map(); // id -> { resolve, timer }
child.stdout.on('data', (d) => {
  stdoutBuf += d;
  let idx;
  while ((idx = stdoutBuf.indexOf('\n')) >= 0) {
    const line = stdoutBuf.slice(0, idx).trim();
    stdoutBuf = stdoutBuf.slice(idx + 1);
    if (!line) continue;
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      continue; // non-JSON noise on stdout
    }
    if (msg.id !== undefined && pending.has(msg.id)) {
      const { resolve, timer } = pending.get(msg.id);
      clearTimeout(timer);
      pending.delete(msg.id);
      resolve(msg);
    }
  }
});

child.on('exit', (code, signal) => {
  for (const [id, { timer }] of [...pending]) {
    clearTimeout(timer);
    pending.delete(id);
    fail(3, `server exited (code=${code} signal=${signal}) before responding`);
  }
});
child.on('error', (e) => fail(3, `spawn failed: ${e.message}`));

function send(msg) {
  child.stdin.write(JSON.stringify(msg) + '\n');
}

function request(method, params, id) {
  return new Promise((resolve) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      fail(2, `timeout after ${TIMEOUT_MS}ms waiting for "${method}" response`);
    }, TIMEOUT_MS);
    pending.set(id, { resolve, timer });
    send({ jsonrpc: '2.0', id, method, params });
  });
}

const init = await request(
  'initialize',
  { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'pi-context7-skill', version: '1.0.0' } },
  1,
);
if (init.error) fail(3, `initialize failed: ${JSON.stringify(init.error)}`);

send({ jsonrpc: '2.0', method: 'notifications/initialized' });

const res = await request('tools/call', { name: toolName, arguments: toolArgs }, 2);
if (res.error) fail(1, `JSON-RPC error from ${toolName}: ${JSON.stringify(res.error)}`);
const result = res.result;
const text = (result?.content ?? []).filter((c) => c.type === 'text').map((c) => c.text).join('\n');

if (result?.isError) {
  console.error(`tool ${toolName} returned an error:`);
  console.error(text || '(no text)');
  child.kill('SIGKILL');
  process.exit(1);
}

let out = text;
if (flags.maxChars > 0 && out.length > flags.maxChars) {
  out += `\n…[truncated ${out.length - flags.maxChars} chars — narrow the query or raise --max-chars]`;
  out = out.slice(0, flags.maxChars + 120);
}
process.stdout.write(out + '\n');
child.kill('SIGKILL');
process.exit(0);
