/**
 * The Skinbuff server.
 *
 * Three jobs, in this order:
 *
 *  1. Serve the skin (the renderer, plus the shared pure modules under `src/` that the
 *     browser imports directly, so state handling has exactly one implementation).
 *  2. Expose a small, stable skin API under `/api/skinbuff/`: the workspace snapshot,
 *     an event stream, and the two writes the UI performs. This is the only contract
 *     the renderer knows, which is what keeps the UI from depending on orchestrator
 *     payload shapes that could not be pinned (docs/api-contract.md).
 *  3. Proxy everything else under `/api/` (and `/healthz`) to the Freebuff
 *     orchestrator verbatim — method, query, body and headers, and notably the launch
 *     cookie the app's own window carries. That cookie is why the proxy copies headers
 *     instead of re-deriving them: the orchestrator's origin guard compares the
 *     `Origin` the page sent, and its launch check reads the cookie, and both have to
 *     arrive as the page sent them.
 *
 * Zero dependencies, loopback only, and it never modifies anything under the installed
 * app.
 */

import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { demoDecision, demoEvents, demoReply, demoSnapshot } from '../src/api/fixtures.mjs';
import { followEventStream, orchestratorBaseUrl, probeOrchestrator, readLiveSnapshot } from '../src/api/orchestrator.mjs';
import { applyEvent, classifyEvent, deriveStats, normalizeSnapshot } from '../src/state/board.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(here, '..');
const DEFAULT_RENDERER_DIR = path.join(ROOT, 'renderer');
const DEFAULT_SRC_DIR = path.join(ROOT, 'src');
const DEFAULT_HOST = '127.0.0.1';
const MAX_BODY_BYTES = 2 * 1024 * 1024;
const MODE_CACHE_MS = 2000;

/** @type {Record<string, string>} */
const CONTENT_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.woff2': 'font/woff2',
  '.map': 'application/json; charset=utf-8',
};

/**
 * Headers that belong to one hop and must not be forwarded either way.
 * @type {Set<string>}
 */
const HOP_BY_HOP = new Set([
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
]);

/**
 * @param {http.ServerResponse} res
 * @param {number} status
 * @param {string} body
 * @param {string} [contentType]
 */
function send(res, status, body, contentType = 'text/plain; charset=utf-8') {
  res.writeHead(status, { 'Content-Type': contentType, 'Cache-Control': 'no-store' });
  res.end(body);
}

/** @param {http.ServerResponse} res @param {number} status @param {unknown} payload */
function sendJson(res, status, payload) {
  send(res, status, JSON.stringify(payload), 'application/json; charset=utf-8');
}

/** @param {unknown} error */
function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

/**
 * The headers Skinbuff passes on to the orchestrator.
 *
 * They are copied rather than re-derived because two of them are load-bearing: the
 * launch cookie (`freebuff_launch_<port>`, HttpOnly, Path=/api — so the page's own
 * request to Skinbuff carries it) is the orchestrator's proof the request came from the
 * app's renderer, and `origin` is what its origin guard compares against the value the
 * shell told it to expect. Drop either and every read answers 401 or 403.
 *
 * @param {http.IncomingMessage} req
 */
function forwardHeaders(req) {
  /** @type {Record<string, string | string[]>} */
  const headers = {};
  for (const [key, value] of Object.entries(req.headers)) {
    if (value === undefined) continue;
    if (key === 'host' || HOP_BY_HOP.has(key)) continue;
    headers[key] = value;
  }
  return headers;
}

/**
 * A request from the local machine itself. Skinbuff binds loopback only, and the Host
 * check refuses a browser that resolved some other name to 127.0.0.1 (DNS rebinding).
 *
 * @param {http.IncomingMessage} req
 */
function isLoopbackRequest(req) {
  const host = req.headers.host;
  if (typeof host !== 'string') return false;
  const name = host.startsWith('[') ? host.slice(1, host.indexOf(']')) : host.split(':')[0];
  return name === '127.0.0.1' || name === 'localhost' || name === '::1';
}

/**
 * Whether a request target tries to leave the directory it names, in raw or
 * percent-encoded form.
 *
 * This is checked against the untouched target on purpose. `new URL` collapses `..`
 * segments while parsing, so a traversal attempt arriving as `/../package.json` would be
 * silently rewritten into a request for `/package.json` before any path guard could see
 * it — the guard would look like it was working while the attempt had already been
 * laundered. Only the path is examined, so a legitimate query value may still contain
 * dots.
 *
 * @param {string} target
 */
function hasTraversal(target) {
  const rawPath = target.split(/[?#]/, 1)[0] ?? '';
  let decoded = rawPath;
  try {
    decoded = decodeURIComponent(rawPath);
  } catch {
    return true; // malformed percent-encoding is never a usable path
  }
  return decoded.split('/').some((segment) => segment === '..');
}

/**
 * @param {http.IncomingMessage} req
 */
function isLoopbackOrigin(req) {
  const origin = req.headers.origin;
  if (!origin) return true; // same-origin fetch or a non-browser client
  try {
    const { hostname } = new URL(origin);
    return hostname === '127.0.0.1' || hostname === 'localhost' || hostname === '::1';
  } catch {
    return false;
  }
}

/** @param {http.IncomingMessage} req @returns {Promise<unknown>} */
function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    /** @type {Buffer[]} */
    const chunks = [];
    let size = 0;
    let settled = false;
    req.on('data', (chunk) => {
      if (settled) return;
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        settled = true;
        reject(new Error('Request body is too large.'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (settled) return;
      settled = true;
      const text = Buffer.concat(chunks).toString('utf8');
      if (!text.trim()) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(text));
      } catch {
        reject(new Error('Request body must be JSON.'));
      }
    });
    req.on('error', (error) => {
      if (!settled) {
        settled = true;
        reject(error);
      }
    });
  });
}

/**
 * @typedef {object} SkinbuffServerOptions
 * @property {string} [host]
 * @property {string} [rendererDir]
 * @property {string} [srcDir]
 * @property {string} [orchestratorUrl]   Where the Freebuff orchestrator listens.
 * @property {typeof fetch} [fetchImpl]
 * @property {number} [demoIntervalMs]    Delay between scripted demo events.
 * @property {number} [heartbeatMs]
 */

/**
 * @param {SkinbuffServerOptions} [options]
 */
export function createSkinbuffServer(options = {}) {
  const host = options.host ?? DEFAULT_HOST;
  const rendererDir = options.rendererDir ?? DEFAULT_RENDERER_DIR;
  const srcDir = options.srcDir ?? DEFAULT_SRC_DIR;
  const orchestratorUrl = (options.orchestratorUrl ?? orchestratorBaseUrl()).replace(/\/+$/, '');
  const fetchImpl = options.fetchImpl ?? fetch;
  const demoIntervalMs = options.demoIntervalMs ?? 900;
  const heartbeatMs = options.heartbeatMs ?? 15_000;

  /** Cached reachability, so a page load does not probe the orchestrator per request. */
  let modeCache = /** @type {{ at: number, mode: 'live' | 'demo', reachable: boolean, status: number | null, error: string | null } | null} */ (null);

  /**
   * Events Skinbuff itself produced (a chat reply, an approval decision). They are kept
   * so `/state` and `/events` agree and a reload does not lose what the user just did.
   * @type {({ type: string } & Record<string, unknown>)[]}
   */
  const journal = [];

  /** @type {Set<http.ServerResponse>} */
  const streamClients = new Set();

  /**
   * Fallback ids, kept in a different namespace from the renderer's `local-*` ids so a
   * reply the client named can never collide with one the server names.
   */
  let serverIds = 0;

  /**
   * The last successful live read, so the state request and the stream request of one
   * page load do not each make the same three orchestrator calls.
   * @type {{ at: number, snapshot: unknown } | null}
   */
  let liveCache = null;

  /** @param {unknown} raw */
  function publish(raw) {
    const frame = `event: skin.event\ndata: ${JSON.stringify(raw)}\n\n`;
    for (const client of streamClients) client.write(frame);
  }

  async function currentMode() {
    const now = Date.now();
    if (modeCache && now - modeCache.at < MODE_CACHE_MS) return modeCache;
    const probe = await probeOrchestrator({ baseUrl: orchestratorUrl, fetchImpl });
    modeCache = {
      at: now,
      mode: probe.reachable ? 'live' : 'demo',
      reachable: probe.reachable,
      status: probe.status,
      error: probe.error,
    };
    return modeCache;
  }

  /**
   * Whether the data behind the skin is real.
   *
   * Being *reachable* and being *authorised* are different questions, and the badge must
   * answer the second one. An orchestrator that is listening but refuses Skinbuff's reads
   * (which is what happens to anything that is not the app's own window — the launch
   * secret reaches only that window over IPC) is a reachable orchestrator with no data.
   * So this returns `live` only when a real read came back; otherwise the skin shows the
   * demo workspace and the status endpoint separately reports that an orchestrator is up.
   * Labelling scripted content `live` because a port answered would be the one lie the
   * whole design is built to avoid.
   *
   * @param {Record<string, string | string[]>} [headers]
   * @returns {Promise<{ mode: 'live' | 'demo', snapshot: unknown }>}
   */
  async function resolveData(headers) {
    const probe = await currentMode();
    if (probe.mode !== 'live') return { mode: 'demo', snapshot: null };

    const now = Date.now();
    if (liveCache && now - liveCache.at < MODE_CACHE_MS) {
      return { mode: 'live', snapshot: liveCache.snapshot };
    }
    const live = await readLiveSnapshot({ baseUrl: orchestratorUrl, fetchImpl, headers });
    if (!live) return { mode: 'demo', snapshot: null };
    liveCache = { at: now, snapshot: live };
    return { mode: 'live', snapshot: live };
  }

  /**
   * The current workspace: the base the data mode justifies, with Skinbuff's own journal
   * applied on top so `/state` and the stream tell the same story.
   *
   * Panels live data does not fill stay empty on purpose — an empty panel under a `live`
   * badge is honest about what has arrived, and it is filled by the event stream rather
   * than by demo content.
   *
   * @param {Record<string, string | string[]>} [headers]
   */
  async function currentState(headers) {
    const data = await resolveData(headers);
    const base = normalizeSnapshot(data.mode === 'live' ? data.snapshot : demoSnapshot(), data.mode);
    base.mode = data.mode;
    let state = base;
    for (const event of journal) state = applyEvent(state, event);
    return state;
  }

  /** @param {string} urlPath @param {string} base @param {http.ServerResponse} res */
  function serveStatic(urlPath, base, res) {
    const relative = urlPath === '/' || urlPath === '' ? 'index.html' : urlPath.replace(/^\/+/, '');
    const absolute = path.resolve(base, relative);
    const inside = path.relative(base, absolute);
    if (inside.startsWith('..') || path.isAbsolute(inside)) {
      send(res, 403, 'Forbidden');
      return;
    }
    if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) {
      send(res, 404, 'Not found');
      return;
    }
    const type = CONTENT_TYPES[path.extname(absolute).toLowerCase()] ?? 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' });
    fs.createReadStream(absolute).pipe(res);
  }

  /**
   * Forward a request to the orchestrator and pipe the answer back untouched.
   *
   * The response is streamed, never buffered, and `content-length` is copied only when
   * the upstream actually sent one: the event stream is chunked, and inventing a length
   * for it would make the browser wait for a body that never completes.
   *
   * @param {http.IncomingMessage} req
   * @param {http.ServerResponse} res
   * @param {string} urlPath
   */
  function proxy(req, res, urlPath) {
    const target = new URL(orchestratorUrl);
    const headers = forwardHeaders(req);
    headers.host = target.host;

    const upstream = http.request(
      {
        host: target.hostname,
        port: target.port,
        method: req.method,
        path: urlPath,
        headers,
        agent: false,
      },
      (upstreamRes) => {
        /** @type {Record<string, string | string[]>} */
        const outHeaders = {};
        for (const [key, value] of Object.entries(upstreamRes.headers)) {
          if (value === undefined) continue;
          if (HOP_BY_HOP.has(key.toLowerCase())) continue;
          outHeaders[key] = value;
        }
        res.writeHead(upstreamRes.statusCode ?? 502, outHeaders);
        // Latency over throughput: an event frame should leave as soon as it arrives.
        res.socket?.setNoDelay(true);
        upstreamRes.pipe(res);
      },
    );

    upstream.on('error', (error) => {
      if (res.headersSent) {
        res.end();
        return;
      }
      sendJson(res, 502, { error: 'orchestrator unreachable', detail: errorMessage(error) });
    });

    // A client that goes away (tab closed, EventSource aborted) must take the upstream
    // request with it, or every reload leaks a socket to the orchestrator.
    res.on('close', () => {
      if (!upstream.destroyed) upstream.destroy();
    });

    if (req.method === 'GET' || req.method === 'HEAD') {
      upstream.end();
      return;
    }
    req.pipe(upstream);
  }

  /**
   * The skin event stream.
   *
   * One stream carries both things the UI needs, and the client distinguishes them with
   * `classifyEvent` rather than with two connections: Skinbuff's own events, and — in
   * live mode — every frame from the orchestrator's `/api/events`, re-emitted under a
   * single event name so the page does not have to guess the orchestrator's names.
   *
   * @param {http.IncomingMessage} req
   * @param {http.ServerResponse} res
   */
  async function openEventStream(req, res) {
    const headers = forwardHeaders(req);
    const data = await resolveData(headers);
    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-store, no-transform',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    res.socket?.setNoDelay(true);
    res.flushHeaders();
    streamClients.add(res);

    const heartbeat = setInterval(() => {
      res.write(': ping\n\n');
    }, heartbeatMs);

    res.write(`event: skin.mode\ndata: ${JSON.stringify({ mode: data.mode, orchestrator: orchestratorUrl })}\n\n`);

    /** @type {AbortController | null} */
    let upstreamAbort = null;
    /** @type {NodeJS.Timeout | null} */
    let demoReplay = null;

    res.on('close', () => {
      clearInterval(heartbeat);
      if (demoReplay) clearInterval(demoReplay);
      upstreamAbort?.abort();
      streamClients.delete(res);
    });

    if (data.mode === 'live') {
      upstreamAbort = new AbortController();
      // Re-emit upstream frames under one event name, so the page never has to guess the
      // orchestrator's event names. Reconnecting is left to the browser: this is a
      // pass-through, not a queue, and the page re-reads /state on reconnect.
      void (async () => {
        try {
          await followEventStream({
            baseUrl: orchestratorUrl,
            fetchImpl,
            path: '/api/events',
            signal: upstreamAbort.signal,
            // The caller's headers, so the page's own launch cookie authenticates this
            // read exactly as it authenticates the shipped UI's EventSource.
            headers,
            onFrame: (frame) => {
              res.write(`event: skin.event\ndata: ${frame.data}\n\n`);
            },
          });
        } catch (error) {
          if (!res.writableEnded) {
            res.write(`event: skin.error\ndata: ${JSON.stringify({ error: errorMessage(error) })}\n\n`);
          }
        }
      })();
      return;
    }

    // Demo mode: replay the scripted timeline so the board, roster and approvals are all
    // exercised the way a live stream would exercise them.
    const events = demoEvents();
    let index = 0;
    demoReplay = setInterval(() => {
      if (index >= events.length) {
        if (demoReplay) clearInterval(demoReplay);
        return;
      }
      res.write(`event: skin.event\ndata: ${JSON.stringify(events[index])}\n\n`);
      index += 1;
    }, demoIntervalMs);
  }

  const server = http.createServer((req, res) => {
    void (async () => {
      const url = new URL(req.url ?? '/', `http://${host}`);
      const route = url.pathname;

      if (hasTraversal(req.url ?? '')) {
        sendJson(res, 403, { error: 'forbidden path' });
        return;
      }

      if (!isLoopbackRequest(req)) {
        sendJson(res, 403, { error: 'forbidden host' });
        return;
      }

      // Health of Skinbuff itself, distinct from the orchestrator's /healthz.
      if (route === '/skinbuff/healthz') {
        const probe = await currentMode();
        sendJson(res, 200, {
          ok: true,
          orchestrator: orchestratorUrl,
          reachable: probe.reachable,
          status: probe.status,
        });
        return;
      }

      if (route === '/api/skinbuff/status') {
        const probe = await currentMode();
        const state = await currentState(forwardHeaders(req));
        sendJson(res, 200, {
          // The data's provenance (the badge) and the orchestrator's presence (the detail
          // line) are reported separately, because they can disagree.
          mode: state.mode,
          orchestrator: {
            url: orchestratorUrl,
            reachable: probe.reachable,
            status: probe.status,
            error: probe.error,
            attached: state.mode === 'live',
          },
          stats: deriveStats(state),
        });
        return;
      }

      if (route === '/api/skinbuff/state') {
        sendJson(res, 200, await currentState(forwardHeaders(req)));
        return;
      }

      if (route === '/api/skinbuff/events') {
        await openEventStream(req, res);
        return;
      }

      if (route === '/api/skinbuff/chat') {
        // The verb is checked before the write guard: a GET is a 405 whether or not it
        // bothered to declare a content type.
        if (req.method !== 'POST') {
          sendJson(res, 405, { error: 'Method not allowed' });
          return;
        }
        const refusal = assertLocalJsonWrite(req);
        if (refusal) {
          sendJson(res, 403, { error: refusal });
          return;
        }
        const body = await readJsonBody(req).catch((error) => error);
        if (body instanceof Error) {
          // A body that does not parse is the caller's mistake, not the server's.
          sendJson(res, 400, { error: errorMessage(body) });
          return;
        }
        const record = body && typeof body === 'object' ? /** @type {Record<string, unknown>} */ (body) : {};
        const text = typeof record.text === 'string' ? record.text.trim() : '';
        if (!text) {
          sendJson(res, 400, { error: 'text is required' });
          return;
        }
        // The renderer's own id if it sent one, so its optimistic copy and this echo are
        // recognised as the same message by the reducer.
        const userMessageId =
          typeof record.id === 'string' && record.id ? record.id : `srv-${(serverIds += 1)}`;
        const userEvent = classifyEvent({
          type: 'message',
          message: { id: userMessageId, role: 'user', text },
        });
        if (userEvent) {
          // Journaled as well as published: `/state` must agree with the stream, or a
          // reload would drop the message the user just sent.
          journal.push(userEvent);
          publish(userEvent);
        }
        const reply = { ...demoReply(text), id: `lead-${(serverIds += 1)}` };
        const leadEvent = classifyEvent({ type: 'message', message: reply });
        if (leadEvent) {
          journal.push(leadEvent);
          publish(leadEvent);
        }
        sendJson(res, 202, { accepted: true, reply });
        return;
      }

      const approvalMatch = /^\/api\/skinbuff\/approvals\/([^/]+)$/.exec(route);
      if (approvalMatch) {
        if (req.method !== 'POST') {
          sendJson(res, 405, { error: 'Method not allowed' });
          return;
        }
        const refusal = assertLocalJsonWrite(req);
        if (refusal) {
          sendJson(res, 403, { error: refusal });
          return;
        }
        const body = await readJsonBody(req).catch((error) => error);
        if (body instanceof Error) {
          sendJson(res, 400, { error: errorMessage(body) });
          return;
        }
        const record = body && typeof body === 'object' ? /** @type {Record<string, unknown>} */ (body) : {};
        const decision = record.decision === 'deny' ? 'deny' : 'allow';
        const event = classifyEvent({
          type: 'approval.resolved',
          approval: { id: decodeURIComponent(approvalMatch[1]), decision },
        });
        if (event) {
          journal.push(event);
          publish(event);
        }
        sendJson(res, 202, { accepted: true, decision, detail: demoDecision(decision) });
        return;
      }

      // Everything below belongs to the orchestrator.
      if (route.startsWith('/api/') || route === '/healthz') {
        proxy(req, res, `${route}${url.search}`);
        return;
      }

      if (req.method !== 'GET' && req.method !== 'HEAD') {
        sendJson(res, 405, { error: 'Method not allowed' });
        return;
      }

      // The renderer, and the pure modules it imports from src/ (one implementation of
      // state handling, shared with this server).
      if (route.startsWith('/src/')) {
        serveStatic(route.replace(/^\/src/, ''), srcDir, res);
        return;
      }
      serveStatic(route, rendererDir, res);
    })().catch((error) => {
      if (!res.headersSent) sendJson(res, 500, { error: errorMessage(error) });
      else res.end();
    });
  });

  /**
   * Writes are same-origin and JSON-typed only, so a page on another origin cannot drive
   * them. Mirrors Converto's guard.
   *
   * @param {http.IncomingMessage} req
   */
  function assertLocalJsonWrite(req) {
    if (!isLoopbackOrigin(req)) return 'Cross-origin requests are refused.';
    const contentType = req.headers['content-type'] ?? '';
    if (!String(contentType).includes('application/json')) return 'Content-Type must be application/json.';
    return null;
  }

  /**
   * Listen on `preferredPort`, or the first free port above it. Pass 0 to let the OS choose.
   *
   * @param {number} [preferredPort]
   * @param {number} [attempts]
   * @returns {Promise<{ port: number, url: string }>}
   */
  function listen(preferredPort = 5174, attempts = 20) {
    return new Promise((resolve, reject) => {
      /** @param {number} port @param {number} left */
      const attempt = (port, left) => {
        /** @param {NodeJS.ErrnoException} error */
        const onError = (error) => {
          server.removeListener('listening', onListening);
          if (error.code === 'EADDRINUSE' && port !== 0 && left > 0) {
            attempt(port + 1, left - 1);
            return;
          }
          reject(error);
        };
        const onListening = () => {
          server.removeListener('error', onError);
          const address = server.address();
          const actual = typeof address === 'object' && address ? address.port : port;
          resolve({ port: actual, url: `http://${host}:${actual}` });
        };
        server.once('error', onError);
        server.once('listening', onListening);
        server.listen(port, host);
      };
      attempt(preferredPort, attempts);
    });
  }

  /** @returns {Promise<void>} */
  function close() {
    for (const client of streamClients) client.end();
    streamClients.clear();
    return new Promise((resolve) => {
      if (!server.listening) {
        resolve();
        return;
      }
      server.close(() => resolve());
    });
  }

  return { server, listen, close, rendererDir, srcDir, host, orchestratorUrl };
}
