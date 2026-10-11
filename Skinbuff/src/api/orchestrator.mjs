/**
 * The Freebuff orchestrator client.
 *
 * Skinbuff never talks to the orchestrator's payload shapes directly in the UI; this
 * module is the one place that does. It handles the two things that are actually
 * pinned (see docs/api-contract.md): the base URL, and that every route — including
 * `/healthz` — answers `401` without the launch secret the app's own window carries.
 *
 * That last fact is why "reachable" and "authorised" are separate questions here.
 * Skinbuff cannot authenticate as the renderer (the launch id reaches only the app's
 * window, over IPC), so it reports reachability from *any* HTTP answer and never
 * claims an authenticated read. Real data arrives the way it does for the shipped UI:
 * through the window's own session cookie, which the server proxy forwards.
 */

/**
 * `headers` allows `string[]` values because the proxy forwards the incoming request's
 * headers verbatim, and Node represents a repeated header as an array.
 *
 * @typedef {{ baseUrl: string, fetchImpl?: typeof fetch, timeoutMs?: number, headers?: Record<string, string | string[]> }} ClientOptions
 */

/** Port the shell points the orchestrator at in dev-UI mode (main.cjs fallback). */
export const DEFAULT_ORCHESTRATOR_PORT = 8787;

/**
 * Where the orchestrator is listening. Honours the same env var the shell uses so an
 * attach with non-default ports needs no extra configuration.
 *
 * @param {Record<string, string | undefined>} [env]
 */
export function orchestratorBaseUrl(env = /** @type {Record<string, string | undefined>} */ (globalThis.process?.env ?? {})) {
  const explicit = env.SKINBUFF_ORCHESTRATOR_URL;
  if (explicit) return explicit.replace(/\/+$/, '');
  const port = Number(env.FREEBUFF_DESKTOP_API_PORT) || DEFAULT_ORCHESTRATOR_PORT;
  return `http://127.0.0.1:${port}`;
}

/**
 * Is anything listening that answers like the orchestrator?
 *
 * `/healthz` requires the launch header, so a 401 is a *success* for this question —
 * it proves a Freebuff orchestrator is there, which a connection refused does not.
 * The body is not read: it cannot be authorised from here.
 *
 * @param {ClientOptions} options
 * @returns {Promise<{ reachable: boolean, status: number | null, error: string | null }>}
 */
export async function probeOrchestrator(options) {
  const fetchImpl = options.fetchImpl ?? fetch;
  const timeoutMs = options.timeoutMs ?? 1500;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(new URL('/healthz', options.baseUrl), {
      method: 'GET',
      signal: controller.signal,
      redirect: 'manual',
    });
    return { reachable: true, status: response.status, error: null };
  } catch (error) {
    return { reachable: false, status: null, error: describeError(error) };
  } finally {
    clearTimeout(timer);
  }
}

/** @param {unknown} error */
export function describeError(error) {
  if (error instanceof Error) {
    // Node reports a refused connection with a code, not a readable message.
    const code = /** @type {{ code?: string }} */ (error).code;
    if (code) return `${error.message} (${code})`;
    return error.message;
  }
  return String(error);
}

/**
 * One JSON request. Never throws: a transport failure is a returned `ok: false`, so a
 * caller can fall back instead of unwinding through a render.
 *
 * @param {ClientOptions & { path: string, method?: string, body?: unknown }} options
 * @returns {Promise<{ ok: boolean, status: number | null, data: unknown, error: string | null }>}
 */
export async function requestJson(options) {
  const fetchImpl = options.fetchImpl ?? fetch;
  const timeoutMs = options.timeoutMs ?? 4000;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(new URL(options.path, options.baseUrl), {
      method: options.method ?? 'GET',
      headers: {
        accept: 'application/json',
        ...(options.body === undefined ? {} : { 'content-type': 'application/json' }),
        ...options.headers,
      },
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
      signal: controller.signal,
    });
    /** @type {unknown} */
    let data = null;
    try {
      data = await response.json();
    } catch {
      data = null;
    }
    return {
      ok: response.ok,
      status: response.status,
      data,
      error: response.ok ? null : `HTTP ${response.status}`,
    };
  } catch (error) {
    return { ok: false, status: null, data: null, error: describeError(error) };
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Parse a Server-Sent Events payload into frames.
 *
 * Pure, so the awkward parts are unit-testable without a socket: CRLF or LF,
 * comments (`:`), `event:`/`id:` fields, a `data:` field repeated across lines, and a
 * final partial block that has not been terminated by a blank line yet.
 *
 * @param {string} text
 * @returns {{ id: string | null, event: string | null, data: string }[]}
 */
export function parseSseFrames(text) {
  /** @type {{ id: string | null, event: string | null, data: string }[]} */
  const frames = [];
  const normalised = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  for (const block of normalised.split('\n\n')) {
    if (!block.trim()) continue;
    /** @type {string[]} */
    const dataLines = [];
    /** @type {string | null} */
    let event = null;
    /** @type {string | null} */
    let id = null;
    let sawField = false;
    for (const line of block.split('\n')) {
      if (line.startsWith(':')) continue; // comment / heartbeat
      if (!line.trim()) continue;
      const separator = line.indexOf(':');
      const field = separator === -1 ? line : line.slice(0, separator);
      let value = separator === -1 ? '' : line.slice(separator + 1);
      if (value.startsWith(' ')) value = value.slice(1);
      if (field === 'data') {
        dataLines.push(value);
        sawField = true;
      } else if (field === 'event') {
        event = value;
        sawField = true;
      } else if (field === 'id') {
        id = value;
        sawField = true;
      }
    }
    if (!sawField) continue;
    frames.push({ id, event, data: dataLines.join('\n') });
  }
  return frames;
}

/**
 * The best workspace state the orchestrator will give this process.
 *
 * Every read here is expected to answer 401 from outside the app, so a failure is the
 * normal case and not an error worth reporting: the caller falls back to the demo. When
 * Skinbuff *is* the app's renderer, the window's launch cookie rides along and these
 * calls start answering with real data, which is why they are written as reads of the
 * routes the shipped UI uses rather than as a special case.
 *
 * @param {ClientOptions} options
 */
export async function readLiveSnapshot(options) {
  const threads = await requestJson({ ...options, path: '/api/threads' });
  const projects = await requestJson({ ...options, path: '/api/projects' });
  const session = await requestJson({ ...options, path: '/api/v1/freebuff/session' });

  const authorised = threads.status !== 401 && projects.status !== 401;
  if (!authorised) return null;

  /** @param {unknown} value */
  const list = (value) => {
    if (Array.isArray(value)) return value;
    if (value && typeof value === 'object') {
      const record = /** @type {Record<string, unknown>} */ (value);
      for (const key of ['threads', 'items', 'data', 'projects']) {
        if (Array.isArray(record[key])) return record[key];
      }
    }
    return [];
  };

  const threadCount = list(threads.data).length;
  const projectCount = list(projects.data).length;

  return {
    workspace: {
      name: /** @type {{ name?: string }} */ (list(projects.data)[0] ?? {})?.name ?? '',
      project: /** @type {{ path?: string }} */ (list(projects.data)[0] ?? {})?.path ?? '',
      branch: /** @type {{ branch?: string }} */ (session.data ?? {})?.branch ?? '',
      startedAt: '',
    },
    // Panels the orchestrator's own contract does not obviously fill stay empty and
    // fill from the event stream instead — see the note in src/state/board.mjs about
    // shapes that could not be pinned.
    messages: [],
    agents: [],
    tasks: [],
    approvals: [],
    activity: [
      {
        at: '',
        text: `Orchestrator read: ${projectCount} project(s), ${threadCount} thread(s)`,
      },
    ],
  };
}

/**
 * Follow an SSE endpoint, calling `onFrame` per frame until the stream ends or the
 * signal aborts. Returns when the stream closes; the caller decides whether to retry.
 *
 * @param {ClientOptions & { path: string, signal: AbortSignal, onFrame: (frame: { id: string | null, event: string | null, data: string }) => void }} options
 */
export async function followEventStream(options) {
  const fetchImpl = options.fetchImpl ?? fetch;
  const response = await fetchImpl(new URL(options.path, options.baseUrl), {
    headers: { accept: 'text/event-stream', ...options.headers },
    signal: options.signal,
  });
  if (!response.ok || !response.body) {
    throw new Error(`event stream refused with HTTP ${response.status}`);
  }
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let pending = '';
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    pending += decoder.decode(value, { stream: true });
    // Keep the trailing partial block: a frame is only complete at a blank line.
    const boundary = pending.lastIndexOf('\n\n');
    if (boundary === -1) continue;
    const ready = pending.slice(0, boundary + 2);
    pending = pending.slice(boundary + 2);
    for (const frame of parseSseFrames(ready)) options.onFrame(frame);
  }
  if (pending.trim()) for (const frame of parseSseFrames(pending)) options.onFrame(frame);
}
