#!/usr/bin/env node
/**
 * Run Skinbuff in a browser: the skin plus the real skin API, and a proxy to the
 * Freebuff orchestrator when one is listening.
 *
 *   node server/dev-server.mjs [--port 5174]
 *
 * 5174 is the default on purpose: it is the port the Freebuff shell loads its renderer
 * from in dev-UI mode (`FREEBUFF_DESKTOP_UI_PORT`), so the same command serves both the
 * standalone preview and the attached skin.
 */

import { parseArgs } from 'node:util';

import { createSkinbuffServer } from './create-server.mjs';

const { values } = parseArgs({
  options: {
    port: { type: 'string', short: 'p' },
    host: { type: 'string' },
    orchestrator: { type: 'string' },
  },
});

const preferredPort = values.port === undefined ? 5174 : Number(values.port);
if (!Number.isInteger(preferredPort) || preferredPort < 0) {
  process.stderr.write(`Invalid --port "${values.port}".\n`);
  process.exit(1);
}

const skinbuff = createSkinbuffServer({
  host: values.host,
  orchestratorUrl: values.orchestrator,
});

try {
  const { url } = await skinbuff.listen(preferredPort);
  // A single machine-readable line for whatever spawned this process.
  process.stdout.write(`SKINBUFF_DEV_SERVER ${url}\n`);
  process.stdout.write(`Skinbuff ready. Open ${url}\n`);
  process.stdout.write(`Orchestrator: ${skinbuff.orchestratorUrl}\n`);
} catch (error) {
  process.stderr.write(`Skinbuff failed to start: ${error instanceof Error ? error.message : String(error)}\n`);
  process.exit(1);
}

for (const signal of /** @type {const} */ (['SIGINT', 'SIGTERM'])) {
  process.on(signal, () => {
    skinbuff.close().finally(() => process.exit(0));
  });
}
