#!/usr/bin/env node
/**
 * Attach Skinbuff to the real Freebuff Desktop app.
 *
 *   node scripts/attach.mjs [--ui-port 5174] [--api-port 8787] [--app <dir>] [--print-env]
 *
 * The app ships an internal dev-UI seam: `electron/main.cjs` reads
 * `FREEBUFF_DEV_UI`, and when it is set the window loads `http://127.0.0.1:<uiPort>/`
 * instead of the bundled renderer, while the orchestrator is told to expect exactly that
 * origin (`FREEBUFF_DESKTOP_UI_ORIGIN`) and to listen on exactly `<apiPort>`. So this
 * script serves the skin on the UI port and starts the app pointed at it. The app's own
 * files are never touched: the seam is an environment variable, and the switch is undone
 * by quitting and reopening the app normally (see README, "Detaching").
 *
 * The shell is single-instance. Launching a second copy while the first is running would
 * hand our window to the instance that is already there — which is listening on its own
 * port, not the one we asked for — so this refuses to start when the API port is in use
 * rather than producing a window that silently rejects the skin's reads.
 *
 * The pure pieces (argument parsing, install discovery, the child environment) are
 * exported so they can be tested without launching anything.
 */

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';

import { createSkinbuffServer } from '../server/create-server.mjs';

/** Defaults the shell itself uses for the dev-UI ports (`electron/main.cjs`). */
export const DEFAULT_UI_PORT = 5174;
export const DEFAULT_API_PORT = 8787;

/** How many consecutive ports to try for the UI, which the shell can be told about. */
const PORT_ATTEMPTS = 20;

/**
 * @param {string} value
 * @param {string} flag
 * @returns {number}
 */
export function toPort(value, flag) {
  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error(`${flag} must be a port number between 1 and 65535, got ${JSON.stringify(value)}.`);
  }
  return port;
}

/**
 * @param {string[]} argv
 * @returns {{ uiPort: number, apiPort: number, app: string | null, printEnv: boolean }}
 */
export function parseAttachArgs(argv) {
  const { values } = parseArgs({
    args: argv,
    options: {
      'ui-port': { type: 'string' },
      'api-port': { type: 'string' },
      app: { type: 'string' },
      'print-env': { type: 'boolean' },
    },
    allowPositionals: false,
  });

  const printEnv = values['print-env'] === true;
  return {
    uiPort:
      values['ui-port'] === undefined
        ? DEFAULT_UI_PORT
        : toPort(String(values['ui-port']), '--ui-port'),
    apiPort:
      values['api-port'] === undefined
        ? DEFAULT_API_PORT
        : toPort(String(values['api-port']), '--api-port'),
    app: values.app === undefined ? null : path.resolve(String(values.app)),
    printEnv,
  };
}

/**
 * Where the desktop app is installed, most likely first.
 *
 * Only the Windows install directory is guessed, because that is the one that exists in
 * this workspace and the one this attach path was written against. Anywhere else, pass
 * `--app <dir>` or set `FREEBUFF_DESKTOP_DIR`.
 *
 * @param {Record<string, string | undefined>} [env]
 * @param {NodeJS.Platform} [platform]
 */
export function appDirCandidates(env = process.env, platform = process.platform) {
  /** @type {string[]} */
  const candidates = [];
  if (env.FREEBUFF_DESKTOP_DIR) candidates.push(env.FREEBUFF_DESKTOP_DIR);
  if (platform === 'win32') {
    const local = env.LOCALAPPDATA;
    if (local) {
      candidates.push(path.join(local, 'Programs', '@codebufffreebuff-desktop'));
      candidates.push(path.join(local, 'Programs', 'freebuff-desktop'));
      candidates.push(path.join(local, 'freebuff-desktop'));
    }
  } else if (platform === 'darwin') {
    candidates.push('/Applications/Freebuff.app/Contents/MacOS');
  } else {
    candidates.push('/opt/freebuff-desktop', '/usr/lib/freebuff-desktop');
  }
  return candidates;
}

/**
 * The app's executable, or `null` when it is not where it is expected.
 *
 * @param {string | null} [explicit]
 * @param {Record<string, string | undefined>} [env]
 * @param {NodeJS.Platform} [platform]
 */
export function findAppExecutable(explicit = null, env = process.env, platform = process.platform) {
  const names = platform === 'win32' ? ['Freebuff.exe'] : ['Freebuff', 'freebuff'];
  const dirs = explicit ? [explicit] : appDirCandidates(env, platform);
  for (const dir of dirs) {
    for (const name of names) {
      const file = path.join(dir, name);
      try {
        if (fs.statSync(file).isFile()) return file;
      } catch {
        // Not there; try the next candidate.
      }
    }
  }
  return null;
}

/**
 * The environment the shell must see for its window to load the skin and its
 * orchestrator to admit it.
 *
 * @param {number} uiPort
 * @param {number} apiPort
 * @param {NodeJS.ProcessEnv} [base]
 * @returns {NodeJS.ProcessEnv & { FREEBUFF_DEV_UI: string, FREEBUFF_DESKTOP_UI_PORT: string, FREEBUFF_DESKTOP_API_PORT: string }}
 */
export function attachEnv(uiPort, apiPort, base = process.env) {
  return {
    ...base,
    FREEBUFF_DEV_UI: '1',
    FREEBUFF_DESKTOP_UI_PORT: String(uiPort),
    FREEBUFF_DESKTOP_API_PORT: String(apiPort),
  };
}

/** @param {number} port @returns {Promise<boolean>} */
function isPortFree(port) {
  return new Promise((resolve) => {
    const probe = net.createServer();
    probe.once('error', () => resolve(false));
    probe.once('listening', () => probe.close(() => resolve(true)));
    probe.listen(port, '127.0.0.1');
  });
}

/**
 * The first free port at or above `preferred`. The UI port can move, because the value is
 * passed on to the shell; the API port cannot, so it is checked separately.
 *
 * @param {number} preferred
 */
export async function findFreePort(preferred) {
  for (let port = preferred; port < preferred + PORT_ATTEMPTS; port += 1) {
    if (await isPortFree(port)) return port;
  }
  throw new Error(`No free port between ${preferred} and ${preferred + PORT_ATTEMPTS - 1}.`);
}

/**
 * Ask the orchestrator's `/healthz` whether it is up. Any HTTP answer counts: the route
 * requires the launch secret, so a 401 *is* proof that an orchestrator is listening
 * (docs/api-contract.md). A refused connection is the only "no".
 *
 * @param {number} apiPort
 * @param {number} [timeoutMs]
 */
export async function waitForOrchestrator(apiPort, timeoutMs = 20_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`http://127.0.0.1:${apiPort}/healthz`, { redirect: 'manual' });
      return { up: true, status: response.status };
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
  return { up: false, status: null };
}

async function main() {
  const options = parseAttachArgs(process.argv.slice(2));

  const exe = findAppExecutable(options.app);
  if (!exe) {
    process.stderr.write(
      'Could not find the Freebuff Desktop app.\n' +
        'Pass --app <dir> with the folder that contains Freebuff.exe, or set FREEBUFF_DESKTOP_DIR.\n' +
        'Expected one of:\n' +
        appDirCandidates()
          .map((dir) => `  ${dir}`)
          .join('\n') +
        '\n',
    );
    process.exitCode = 1;
    return;
  }

  if (options.printEnv) {
    process.stdout.write(
      `# Launch this yourself:\n` +
        `FREEBUFF_DEV_UI=1 FREEBUFF_DESKTOP_UI_PORT=${options.uiPort} FREEBUFF_DESKTOP_API_PORT=${options.apiPort} "${exe}"\n`,
    );
    return;
  }

  if (!(await isPortFree(options.apiPort))) {
    process.stderr.write(
      `Port ${options.apiPort} is already in use, so Freebuff is most likely already running.\n` +
        'The app is single-instance: a second launch would reuse the running window, which is\n' +
        'listening on a different port, and the skin would load but never receive data.\n' +
        'Quit Freebuff completely, then run this again.\n',
    );
    process.exitCode = 1;
    return;
  }

  const uiPort = await findFreePort(options.uiPort);
  if (uiPort !== options.uiPort) {
    process.stdout.write(`Port ${options.uiPort} is busy; serving the skin on ${uiPort} instead.\n`);
  }

  const apiUrl = `http://127.0.0.1:${options.apiPort}`;
  const skinbuff = createSkinbuffServer({
    // Explicit rather than inferred from the environment, so the proxy targets the port we
    // are about to tell the shell to listen on even if the ambient env says otherwise.
    orchestratorUrl: apiUrl,
    host: '127.0.0.1',
  });

  const { url } = await skinbuff.listen(uiPort);

  process.stdout.write(`Skinbuff serving ${url}\n`);
  process.stdout.write(`Orchestrator expected at ${apiUrl}\n`);
  process.stdout.write(`Launching ${exe}\n`);

  const child = spawn(exe, [], {
    env: attachEnv(uiPort, options.apiPort),
    detached: true,
    stdio: 'ignore',
  });
  child.unref();
  process.stdout.write(`Freebuff started (pid ${child.pid}).\n`);

  const health = await waitForOrchestrator(options.apiPort);
  process.stdout.write(
    health.up
      ? `Orchestrator is listening on ${apiUrl} (HTTP ${health.status}).`
      : `Orchestrator did not answer on ${apiUrl} within the wait; the skin will show demo data until it does.`,
  );
  process.stdout.write(
    `\nAttached. Keep this process running while you use the skin.\n` +
      `Detach by quitting Freebuff, then stop this with Ctrl+C. The app's own files were not changed.\n`,
  );

  for (const signal of /** @type {const} */ (['SIGINT', 'SIGTERM'])) {
    process.on(signal, () => {
      process.stdout.write('\nSkinbuff stopped serving. Quit Freebuff to finish detaching.\n');
      skinbuff.close().finally(() => process.exit(0));
    });
  }
}

// Only run when invoked directly, so the helpers above can be imported by a test.
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  main().catch((error) => {
    process.stderr.write(`Attach failed: ${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  });
}
