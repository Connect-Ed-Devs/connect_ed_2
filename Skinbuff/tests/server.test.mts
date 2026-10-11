import assert from 'node:assert/strict';
import http from 'node:http';
import { describe, test } from 'node:test';

import { createSkinbuffServer } from '../server/create-server.mjs';

/** An unreachable address, for the "no orchestrator" cases. */
const NOWHERE = 'http://127.0.0.1:1';

type Recorded = { method: string, url: string, headers: http.IncomingHttpHeaders, body: string };

/** @param {http.Server} server @param {number} port */
function listen(server: http.Server, port: number) {
  return new Promise<number>((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', () => {
      server.removeListener('error', reject);
      const address = server.address();
      resolve(typeof address === 'object' && address ? address.port : port);
    });
  });
}

/** @param {http.Server} server */
function close(server: http.Server) {
  return new Promise<void>((resolve) => {
    if (!server.listening) {
      resolve();
      return;
    }
    server.close(() => resolve());
  });
}

/** @param {http.ServerResponse} res @param {number} status @param {unknown} body */
function send(res: http.ServerResponse, status: number, body: unknown) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
}

/**
 * A stand-in for the Freebuff orchestrator that records what it was sent, which is how
 * the proxy's forwarding behaviour is actually checked rather than assumed.
 *
 * @param {(req: http.IncomingMessage, res: http.ServerResponse, recorded: Recorded) => unknown} handler
 */
async function startFakeOrchestrator(handler: (req: http.IncomingMessage, res: http.ServerResponse, recorded: Recorded) => unknown) {
  /** @type {Recorded[]} */
  const requests: Recorded[] = [];
  const server = http.createServer((req, res) => {
    /** @type {Buffer[]} */
    const chunks: Buffer[] = [];
    req.on('data', (chunk: Buffer) => chunks.push(chunk));
    req.on('end', () => {
      const recorded: Recorded = {
        method: req.method ?? '',
        url: req.url ?? '',
        headers: req.headers,
        body: Buffer.concat(chunks).toString('utf8'),
      };
      requests.push(recorded);
      void Promise.resolve(handler(req, res, recorded)).catch(() => {
        if (!res.headersSent) send(res, 500, { error: 'fake handler failed' });
      });
    });
  });
  const port = await listen(server, 0);
  return { url: `http://127.0.0.1:${port}`, requests, close: () => close(server) };
}

/** @param {string} orchestratorUrl @param {Record<string, unknown>} [options] */
async function startSkinbuff(orchestratorUrl: string, options: Record<string, unknown> = {}) {
  const skinbuff = createSkinbuffServer({ orchestratorUrl, ...options });
  const { url, port } = await skinbuff.listen(0);
  return { url, port, close: () => skinbuff.close() };
}

/**
 * Incrementally read a stream so a test can assert what had *not* arrived yet, which is
 * the only way to prove the server is not buffering.
 *
 * @param {string} url
 */
async function streamReader(url: string) {
  const controller = new AbortController();
  const response = await fetch(url, { headers: { accept: 'text/event-stream' }, signal: controller.signal });
  const reader = response.body?.getReader();
  if (!reader) throw new Error('no stream body');
  const decoder = new TextDecoder();
  let buffer = '';
  return {
    get text() {
      return buffer;
    },
    /** @param {string} needle @param {number} [timeoutMs] */
    async waitFor(needle: string, timeoutMs = 5000) {
      const deadline = Date.now() + timeoutMs;
      while (!buffer.includes(needle)) {
        const budget = deadline - Date.now();
        if (budget <= 0) throw new Error(`timed out waiting for ${JSON.stringify(needle)}; got: ${buffer}`);
        const timeout = new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error(`timed out waiting for ${JSON.stringify(needle)}; got: ${buffer}`)), budget),
        );
        const { value, done } = await Promise.race([reader.read(), timeout]);
        if (done) throw new Error(`stream ended before ${JSON.stringify(needle)}; got: ${buffer}`);
        buffer += decoder.decode(value, { stream: true });
      }
      return buffer;
    },
    stop() {
      controller.abort();
      void reader.cancel().catch(() => {});
    },
  };
}

/** A raw request, so a test can set a Host header (fetch refuses to). */
function rawRequest(port: number, path: string, headers: Record<string, string> = {}) {
  return new Promise<{ status: number, body: string }>((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port, path, method: 'GET', headers }, (res) => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (chunk: string) => {
        body += chunk;
      });
      res.on('end', () => resolve({ status: res.statusCode ?? 0, body }));
    });
    req.on('error', reject);
    req.end();
  });
}

describe('static renderer', () => {
  test('serves the skin at /', async () => {
    const skin = await startSkinbuff(NOWHERE);
    try {
      const response = await fetch(`${skin.url}/`);
      assert.equal(response.status, 200);
      assert.match(response.headers.get('content-type') ?? '', /text\/html/);
      const html = await response.text();
      assert.match(html, /Skinbuff/);
      assert.match(html, /id="mode-badge"/);
      assert.match(html, /Content-Security-Policy/);
    } finally {
      await skin.close();
    }
  });

  test('serves the shared state engine, so the browser imports the same reducer the server uses', async () => {
    const skin = await startSkinbuff(NOWHERE);
    try {
      const response = await fetch(`${skin.url}/src/state/board.mjs`);
      assert.equal(response.status, 200);
      assert.match(response.headers.get('content-type') ?? '', /javascript/);
      assert.match(await response.text(), /export function applyEvent/);
    } finally {
      await skin.close();
    }
  });

  test('serves the view modules the shell imports', async () => {
    const skin = await startSkinbuff(NOWHERE);
    try {
      for (const path of ['/app.js', '/app.css', '/dom.js', '/views/board.js', '/views/chat.js', '/views/team.js', '/views/approvals.js']) {
        const response = await fetch(`${skin.url}${path}`);
        assert.equal(response.status, 200, `expected ${path} to be served`);
      }
    } finally {
      await skin.close();
    }
  });

  test('refuses to walk out of the served directory', async () => {
    const skin = await startSkinbuff(NOWHERE);
    try {
      // The raw target is refused before the URL parser can normalise the `..` away, so
      // this asserts the guard itself rather than the accident that `/../x` collapses.
      for (const attempt of ['/../package.json', '/src/../../package.json', '/%2e%2e/package.json']) {
        const escaped = await rawRequest(skin.port, attempt);
        assert.equal(escaped.status, 403, `expected ${attempt} to be refused`);
        assert.ok(!escaped.body.includes('"name"'), 'a traversal attempt must never serve a file from outside');
      }
      const missing = await rawRequest(skin.port, '/nope.txt');
      assert.equal(missing.status, 404);
    } finally {
      await skin.close();
    }
  });

  test('refuses a Host that is not loopback, so a rebound name cannot reach it', async () => {
    const skin = await startSkinbuff(NOWHERE);
    try {
      const response = await rawRequest(skin.port, '/', { host: 'evil.test' });
      assert.equal(response.status, 403);
      assert.match(response.body, /forbidden host/);
    } finally {
      await skin.close();
    }
  });
});

describe('data mode is about the data, not the port', () => {
  test('with nothing listening, the workspace is the demo and the status says unreachable', async () => {
    const skin = await startSkinbuff(NOWHERE);
    try {
      const state = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      assert.equal(state.mode, 'demo');
      assert.ok(state.tasks.length > 0);

      const status = await (await fetch(`${skin.url}/api/skinbuff/status`)).json();
      assert.equal(status.mode, 'demo');
      assert.equal(status.orchestrator.reachable, false);
      assert.equal(status.orchestrator.attached, false);
      assert.equal(status.stats.openTasks > 0, true);
    } finally {
      await skin.close();
    }
  });

  test('a reachable orchestrator that refuses the reads is still demo data, and says so', async () => {
    const orchestrator = await startFakeOrchestrator((_req, res) => send(res, 401, { error: 'unauthorized' }));
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const status = await (await fetch(`${skin.url}/api/skinbuff/status`)).json();
      assert.equal(status.mode, 'demo', 'scripted content must never be labelled live');
      assert.equal(status.orchestrator.reachable, true);
      assert.equal(status.orchestrator.attached, false);

      const state = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      assert.equal(state.mode, 'demo');
      assert.ok(state.tasks.length > 0);
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });

  test('readable orchestrator data is live, and panels it does not fill stay empty', async () => {
    const orchestrator = await startFakeOrchestrator((req, res) => {
      if (req.url === '/api/threads') return send(res, 200, { threads: [{ id: 'c1' }] });
      if (req.url === '/api/projects') return send(res, 200, { projects: [{ name: 'Skinbuff', path: 'AIWork' }] });
      return send(res, 200, { branch: 'Experimental-Features' });
    });
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const state = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      assert.equal(state.mode, 'live');
      assert.equal(state.workspace.project, 'AIWork');
      assert.equal(state.workspace.branch, 'Experimental-Features');
      assert.deepEqual(state.tasks, [], 'a live panel with no data must be empty, not demo content');
      assert.match(state.activity[0].text, /Orchestrator read/);

      const status = await (await fetch(`${skin.url}/api/skinbuff/status`)).json();
      assert.equal(status.orchestrator.attached, true);
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });
});

describe('the proxy', () => {
  test('forwards method, path, query, cookie and origin verbatim, and returns the answer untouched', async () => {
    const orchestrator = await startFakeOrchestrator((_req, res) => {
      res.writeHead(418, { 'content-type': 'application/json', 'x-upstream': 'yes' });
      res.end(JSON.stringify({ teapot: true }));
    });
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const response = await fetch(`${skin.url}/api/project/changes?file=a%20b.ts&mode=diff`, {
        headers: { cookie: 'freebuff_launch_8787=secret', origin: 'http://127.0.0.1:5174' },
      });
      assert.equal(response.status, 418, 'the upstream status must pass through, not be normalised');
      assert.equal(response.headers.get('x-upstream'), 'yes');
      assert.deepEqual(await response.json(), { teapot: true });

      const recorded = orchestrator.requests[0]!;
      assert.equal(recorded.method, 'GET');
      // The query arrives byte-for-byte as sent, escaping included.
      assert.equal(recorded.url, '/api/project/changes?file=a%20b.ts&mode=diff');
      assert.equal(recorded.headers.cookie, 'freebuff_launch_8787=secret');
      assert.equal(recorded.headers.origin, 'http://127.0.0.1:5174');
      assert.equal(recorded.headers.host, new URL(orchestrator.url).host, 'host must be rewritten to the orchestrator');
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });

  test('forwards a POST body unchanged', async () => {
    const orchestrator = await startFakeOrchestrator((_req, res) => send(res, 200, { ok: true }));
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const body = JSON.stringify({ path: 'a.ts', line: 3 });
      const response = await fetch(`${skin.url}/api/diff-comments`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', cookie: 'c=1' },
        body,
      });
      assert.equal(response.status, 200);
      assert.equal(orchestrator.requests[0]!.body, body);
      assert.equal(orchestrator.requests[0]!.headers.cookie, 'c=1');
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });

  test('drops hop-by-hop response headers instead of relaying them', async () => {
    const orchestrator = await startFakeOrchestrator((_req, res) => {
      // A header Node will not synthesise itself, so what the client sees can only have
      // come from the relay. (`keep-alive` would be a poor probe: the Skinbuff server
      // emits its own, which would make this pass for the wrong reason.)
      res.writeHead(200, {
        'content-type': 'text/plain',
        'proxy-authenticate': 'Basic realm="upstream"',
        trailer: 'x-checksum',
        'x-keep': 'me',
      });
      res.end('hello');
    });
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const response = await fetch(`${skin.url}/api/anything`);
      assert.equal(await response.text(), 'hello');
      assert.equal(response.headers.get('proxy-authenticate'), null, 'hop-by-hop header leaked through');
      assert.equal(response.headers.get('trailer'), null, 'hop-by-hop header leaked through');
      assert.equal(response.headers.get('x-keep'), 'me');
      assert.match(response.headers.get('content-type') ?? '', /text\/plain/);
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });

  test('reports an unreachable orchestrator as 502 instead of hanging', async () => {
    const skin = await startSkinbuff(NOWHERE);
    try {
      const response = await fetch(`${skin.url}/api/threads`);
      assert.equal(response.status, 502);
      const body = await response.json();
      assert.equal(body.error, 'orchestrator unreachable');
    } finally {
      await skin.close();
    }
  });

  test('proxies /healthz rather than answering it as its own', async () => {
    const orchestrator = await startFakeOrchestrator((_req, res) => send(res, 200, { ok: true, pid: 1, port: 2 }));
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const response = await fetch(`${skin.url}/healthz`);
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), { ok: true, pid: 1, port: 2 });
      assert.equal(orchestrator.requests[0]!.url, '/healthz');
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });

  test('keeps the skin API local even while an orchestrator is attached', async () => {
    const orchestrator = await startFakeOrchestrator((_req, res) => send(res, 200, { projects: [], threads: [] }));
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const status = await (await fetch(`${skin.url}/api/skinbuff/status`)).json();
      assert.equal(status.orchestrator.reachable, true);
      assert.ok(
        orchestrator.requests.every((recorded) => !recorded.url.startsWith('/api/skinbuff/')),
        'skin API requests must not be forwarded',
      );
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });
});

describe('the event stream', () => {
  test('does not buffer: a frame is delivered before the next one is even sent', async () => {
    /** @type {() => void} */
    let release = () => {};
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    const orchestrator = await startFakeOrchestrator(async (req, res) => {
      if (req.url === '/api/events') {
        res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-store' });
        res.write('data: first\n\n');
        await gate;
        res.write('data: second\n\n');
        res.end();
        return;
      }
      if (req.url === '/api/projects') return send(res, 200, { projects: [] });
      return send(res, 200, { threads: [] });
    });
    const skin = await startSkinbuff(orchestrator.url);
    const stream = await streamReader(`${skin.url}/api/skinbuff/events`);
    try {
      await stream.waitFor('data: first');
      assert.ok(
        !stream.text.includes('data: second'),
        'the second frame must not be present before the upstream has sent it — that would mean buffering',
      );
      release();
      await stream.waitFor('data: second');
    } finally {
      stream.stop();
      await skin.close();
      await orchestrator.close();
    }
  });

  test('reports the data mode on connect, before any event', async () => {
    const skin = await startSkinbuff(NOWHERE, { demoIntervalMs: 15 });
    const stream = await streamReader(`${skin.url}/api/skinbuff/events`);
    try {
      await stream.waitFor('event: skin.mode');
      assert.match(stream.text, /"mode":"demo"/);
    } finally {
      stream.stop();
      await skin.close();
    }
  });

  test('replays the demo timeline for a client that is not attached', async () => {
    const skin = await startSkinbuff(NOWHERE, { demoIntervalMs: 15 });
    const stream = await streamReader(`${skin.url}/api/skinbuff/events`);
    try {
      await stream.waitFor('task.moved');
      assert.ok(stream.text.includes('event: skin.event'));
    } finally {
      stream.stop();
      await skin.close();
    }
  });
});

describe('writes', () => {
  test('a chat message is journaled, echoed with the id the client chose, and survives a reload', async () => {
    const skin = await startSkinbuff(NOWHERE);
    const stream = await streamReader(`${skin.url}/api/skinbuff/events`);
    try {
      await stream.waitFor('event: skin.mode');

      const response = await fetch(`${skin.url}/api/skinbuff/chat`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', origin: `http://127.0.0.1:${skin.port}` },
        body: JSON.stringify({ text: 'mark the whole class present', id: 'local-9' }),
      });
      assert.equal(response.status, 202);
      const payload = await response.json();
      assert.equal(payload.reply.role, 'lead');

      // The same id comes back on the stream, which is what lets the renderer ignore its
      // own optimistic copy rather than rendering the message twice.
      await stream.waitFor('"id":"local-9"');

      const state = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      const ids = state.messages.map((message: { id: string }) => message.id);
      assert.ok(ids.includes('local-9'));
      assert.equal(ids.filter((id: string) => id === 'local-9').length, 1);
      assert.ok(state.messages.some((message: { role: string }) => message.role === 'lead'));
    } finally {
      stream.stop();
      await skin.close();
    }
  });

  test('a message sent without an id still works and gets a server-side id', async () => {
    const skin = await startSkinbuff(NOWHERE);
    try {
      const response = await fetch(`${skin.url}/api/skinbuff/chat`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ text: 'no id here' }),
      });
      assert.equal(response.status, 202);
      const state = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      assert.ok(state.messages.some((message: { id: string }) => message.id.startsWith('srv-')));
    } finally {
      await skin.close();
    }
  });

  test('an approval decision is journaled and visible in the workspace', async () => {
    const skin = await startSkinbuff(NOWHERE);
    try {
      const before = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      assert.equal(before.approvals.find((a: { id: string }) => a.id === 'p3').status, 'pending');

      const response = await fetch(`${skin.url}/api/skinbuff/approvals/p3`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ decision: 'deny' }),
      });
      assert.equal(response.status, 202);
      assert.match((await response.json()).detail, /nothing was written/i);

      const after = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      assert.equal(after.approvals.find((a: { id: string }) => a.id === 'p3').status, 'denied');
      assert.equal(after.approvals.find((a: { id: string }) => a.id === 'p1').status, 'pending', 'other approvals are untouched');
    } finally {
      await skin.close();
    }
  });

  test('refuses writes that are cross-origin, untyped, empty or the wrong verb, and changes nothing', async () => {
    const skin = await startSkinbuff(NOWHERE);
    try {
      const before = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();

      const crossOrigin = await fetch(`${skin.url}/api/skinbuff/chat`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', origin: 'http://evil.test' },
        body: JSON.stringify({ text: 'hi' }),
      });
      assert.equal(crossOrigin.status, 403);

      const untyped = await fetch(`${skin.url}/api/skinbuff/chat`, {
        method: 'POST',
        headers: { 'content-type': 'text/plain' },
        body: 'hi',
      });
      assert.equal(untyped.status, 403);

      const empty = await fetch(`${skin.url}/api/skinbuff/chat`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ text: '   ' }),
      });
      assert.equal(empty.status, 400);

      const wrongVerb = await fetch(`${skin.url}/api/skinbuff/chat`);
      assert.equal(wrongVerb.status, 405);

      // An unparseable body is the caller's error, so it is a 400, not a 500.
      const badJson = await fetch(`${skin.url}/api/skinbuff/chat`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: '{not json',
      });
      assert.equal(badJson.status, 400);

      const after = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      assert.deepEqual(
        after.messages.map((message: { id: string }) => message.id),
        before.messages.map((message: { id: string }) => message.id),
        'a refused write must leave the workspace exactly as it was',
      );
    } finally {
      await skin.close();
    }
  });
});
