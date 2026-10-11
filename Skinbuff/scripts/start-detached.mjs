#!/usr/bin/env node
/**
 * Start the Skinbuff dev server detached, so it survives the shell that launched it.
 * Prints the pid and the log paths, then exits immediately.
 *
 *   node scripts/start-detached.mjs [logPath] [--port 5174] [--orchestrator http://127.0.0.1:8787]
 *
 * Same shape as Converto's launcher, including the `SKINBUFF_DEV_SERVER <url>` line the
 * child writes on stdout: that single line is how a caller learns the port the server
 * actually bound when `--port` was in use.
 */

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..');

const args = process.argv.slice(2);
const logPath = args.find((arg) => !arg.startsWith('--')) ?? path.join(root, '.tmp', 'dev-server.log');
const portIndex = args.indexOf('--port');
const port = portIndex === -1 ? undefined : args[portIndex + 1];
const orchestratorIndex = args.indexOf('--orchestrator');
const orchestrator = orchestratorIndex === -1 ? undefined : args[orchestratorIndex + 1];

fs.mkdirSync(path.dirname(logPath), { recursive: true });
const out = fs.openSync(logPath, 'a');
const err = fs.openSync(`${logPath}.err`, 'a');

const serverArgs = [path.join(root, 'server', 'dev-server.mjs')];
if (port !== undefined) serverArgs.push('--port', port);
if (orchestrator !== undefined) serverArgs.push('--orchestrator', orchestrator);

const child = spawn(process.execPath, serverArgs, {
  cwd: root,
  detached: true,
  stdio: ['ignore', out, err],
});

child.unref();

process.stdout.write(`pid=${child.pid}\n`);
process.stdout.write(`log=${logPath}\n`);
process.stdout.write(`err=${logPath}.err\n`);
