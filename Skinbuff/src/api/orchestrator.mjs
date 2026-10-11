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
 * The routes Skinbuff writes to, taken verbatim from the shipped renderer rather than
 * guessed. See docs/api-contract.md for the extraction that produced them.
 *
 * Chat is the Vercel AI SDK's `HttpChatTransport`, whose default `api` is `/api/chat`, so
 * a send is an AI SDK request and the reply is an AI SDK UI message stream — not a JSON
 * round trip. "Approvals" in the app are git invitations, and the three routes below are
 * exactly the ones the app's own renderer calls.
 */
export const CHAT_PATH = '/api/chat';
export const THREADS_PATH = '/api/threads';
export const GIT_INVITATION = {
  inspect: '/api/ad/invitation/git/inspect',
  approve: '/api/ad/invitation/git/approve',
  decline: '/api/ad/invitation/git/decline',
};

/** The header the orchestrator sets on a UI message stream (`UI_MESSAGE_STREAM_HEADERS`). */
export const UI_MESSAGE_STREAM_HEADER = 'x-vercel-ai-ui-message-stream';

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

  const projectList = list(projects.data);
  const threadList = list(threads.data);
  const threadCount = threadList.length;
  const projectCount = projectList.length;
  const firstProject = /** @type {{ name?: string, path?: string }} */ (projectList[0] ?? {});
  const firstThread = /** @type {{ id?: string }} */ (threadList[0] ?? {});

  return {
    workspace: {
      name: firstProject?.name ?? '',
      project: firstProject?.path ?? '',
      branch: /** @type {{ branch?: string }} */ (session.data ?? {})?.branch ?? '',
      startedAt: '',
      // Carried because a real chat send and a real invitation decision both need the
      // thread they belong to, and this is the only read that returns one.
      threadId: firstThread?.id ?? '',
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

/**
 * A Skinbuff message as the AI SDK expects it: a UI message with typed parts.
 *
 * The skin's own roles are `user | lead | agent | system`; the protocol knows
 * `user | assistant | system`. The Lead and the specialist agents are both the assistant
 * as far as the transport is concerned.
 *
 * @param {{ id?: string, role?: string, text?: string }[]} messages
 */
export function toUiMessages(messages) {
  return messages
    .filter((message) => typeof message?.text === 'string' && message.text.trim() !== '')
    .map((message, index) => ({
      id: typeof message.id === 'string' && message.id ? message.id : `m${index}`,
      role: message.role === 'user' ? 'user' : message.role === 'system' ? 'system' : 'assistant',
      parts: [{ type: 'text', text: message.text }],
    }));
}

/**
 * The body `HttpChatTransport.sendMessages` builds, read out of the app's own bundle:
 *
 * ```js
 * body: { ...resolvedBody, ...options.body, id: chatId, messages, trigger, messageId }
 * ```
 *
 * `trigger` and `messageId` are always assigned but are frequently `undefined`, and
 * `JSON.stringify` drops undefined properties, so a normal send serialises as `{ id,
 * messages }`. They are omitted here rather than sent as null.
 *
 * @param {{ threadId: string, messages: { id?: string, role?: string, text?: string }[], trigger?: string, messageId?: string }} options
 */
export function buildChatBody(options) {
  /** @type {Record<string, unknown>} */
  const body = { id: options.threadId, messages: toUiMessages(options.messages) };
  if (options.trigger !== undefined) body.trigger = options.trigger;
  if (options.messageId !== undefined) body.messageId = options.messageId;
  return body;
}

/**
 * Read the assistant's text out of an AI SDK UI message stream.
 *
 * The wire format is pinned from the orchestrator's own writer
 * (`JsonToSseTransformStream` + `createUIMessageStreamResponse`): Server-Sent Events whose
 * `data:` payload is one JSON chunk, terminated by `data: [DONE]`, under the
 * `content-type: text/event-stream` and `x-vercel-ai-ui-message-stream: v1` headers.
 *
 * Only `text-delta` carries prose. Both `delta` (the UI message stream) and `text` (the
 * model stream) are accepted, because the two chunk shapes differ between AI SDK
 * versions and picking the wrong one would silently produce an empty reply. Unrecognised
 * chunk types are ignored rather than treated as errors, so a new chunk type upstream
 * degrades to less text, never to a crash.
 *
 * Pure, so the awkward parts — partial frames, the sentinel, an error chunk — are
 * unit-testable without a socket.
 *
 * @param {string} text
 * @returns {{ text: string, error: string | null, finished: boolean }}
 */
export function parseUiMessageStream(text) {
  let out = '';
  /** @type {string | null} */
  let error = null;
  let finished = false;
  for (const frame of parseSseFrames(text)) {
    const data = frame.data.trim();
    if (!data) continue;
    if (data === '[DONE]') {
      finished = true;
      continue;
    }
    /** @type {Record<string, unknown> | null} */
    let part = null;
    try {
      const parsed = JSON.parse(data);
      part = parsed && typeof parsed === 'object' ? parsed : null;
    } catch {
      continue;
    }
    if (!part) continue;
    if (part.type === 'text-delta') {
      const chunk = part.delta ?? part.text;
      if (typeof chunk === 'string') out += chunk;
      continue;
    }
    if (part.type === 'error') {
      const detail = part.errorText ?? part.error;
      error = typeof detail === 'string' && detail ? detail : 'the agent reported an error';
    }
  }
  return { text: out, error, finished };
}

/**
 * Send one turn and consume the reply stream.
 *
 * Never throws: a refusal is an `ok: false` carrying the orchestrator's own status, which
 * is what lets the caller refuse to invent a reply. When the stream is rejected outright
 * (401/403 — the usual answer to anything that is not the app's own window) the body is
 * read as text precisely so the real error can be reported instead of a generic one.
 *
 * `headers` must be the page's own headers, because the launch cookie is what authorises
 * this call when Skinbuff is the app's renderer.
 *
 * @param {ClientOptions & {
 *   threadId: string,
 *   messages: { id?: string, role?: string, text?: string }[],
 *   trigger?: string,
 *   messageId?: string,
 *   signal?: AbortSignal,
 *   onDelta?: (delta: string) => void,
 * }} options
 * @returns {Promise<{ ok: boolean, status: number | null, error: string | null, text: string, finished: boolean }>}
 */
export async function sendChat(options) {
  const fetchImpl = options.fetchImpl ?? fetch;
  try {
    const response = await fetchImpl(new URL(CHAT_PATH, options.baseUrl), {
      method: 'POST',
      headers: {
        accept: 'text/event-stream',
        'content-type': 'application/json',
        ...options.headers,
      },
      body: JSON.stringify(buildChatBody(options)),
      signal: options.signal,
    });

    if (!response.ok) {
      let detail = '';
      try {
        detail = (await response.text()).slice(0, 200).trim();
      } catch {
        detail = '';
      }
      return {
        ok: false,
        status: response.status,
        error: `HTTP ${response.status}${detail ? `: ${detail}` : ''}`,
        text: '',
        finished: false,
      };
    }

    if (!response.body) {
      return { ok: false, status: response.status, error: 'the reply stream was empty', text: '', finished: false };
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let pending = '';
    let text = '';
    /** @type {string | null} */
    let error = null;
    let finished = false;

    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      pending += decoder.decode(value, { stream: true });
      // A frame is only complete at a blank line, so the trailing partial block is kept.
      const boundary = pending.lastIndexOf('\n\n');
      if (boundary === -1) continue;
      const ready = pending.slice(0, boundary + 2);
      pending = pending.slice(boundary + 2);
      const parsed = parseUiMessageStream(ready);
      if (parsed.text) {
        text += parsed.text;
        options.onDelta?.(parsed.text);
      }
      if (parsed.error) error = parsed.error;
      if (parsed.finished) finished = true;
    }
    if (pending.trim()) {
      const parsed = parseUiMessageStream(pending);
      if (parsed.text) {
        text += parsed.text;
        options.onDelta?.(parsed.text);
      }
      if (parsed.error) error = parsed.error;
      if (parsed.finished) finished = true;
    }

    return { ok: true, status: response.status, error, text, finished };
  } catch (cause) {
    return { ok: false, status: null, error: describeError(cause), text: '', finished: false };
  }
}

/**
 * Resolve a git invitation — the app's approval flow.
 *
 * Both bodies are the ones the shipped renderer sends. `approve` carries the invitation's
 * `token` and `identity` and a literal `confirmed: true`, which is the app's own
 * acknowledgement that the user saw what they were approving; a caller that does not have
 * the token from an inspected invitation cannot approve, and should not pretend to.
 *
 * @param {ClientOptions & {
 *   decision: 'approve' | 'decline',
 *   threadId: string,
 *   invitationId: string,
 *   token?: string,
 *   files?: unknown,
 *   identity?: unknown,
 * }} options
 */
export async function decideGitInvitation(options) {
  if (options.decision === 'approve') {
    return requestJson({
      ...options,
      path: GIT_INVITATION.approve,
      method: 'POST',
      body: {
        threadId: options.threadId,
        invitationId: options.invitationId,
        ...(options.token === undefined ? {} : { token: options.token }),
        ...(options.files === undefined ? {} : { files: options.files }),
        ...(options.identity === undefined ? {} : { identity: options.identity }),
        confirmed: true,
      },
    });
  }
  return requestJson({
    ...options,
    path: GIT_INVITATION.decline,
    method: 'POST',
    body: { threadId: options.threadId, invitationId: options.invitationId },
  });
}

/**
 * Inspect a git invitation — the read that returns the `token` an approval needs.
 *
 * @param {ClientOptions & { threadId: string, invitationId: string }} options
 */
export async function inspectGitInvitation(options) {
  return requestJson({
    ...options,
    path: GIT_INVITATION.inspect,
    method: 'POST',
    body: { threadId: options.threadId, invitationId: options.invitationId },
  });
}

/**
 * Create a thread, which a chat send needs an id for. The app's own renderer posts
 * `{ projectPath }` to `/api/threads`, so the reply is whatever it returns.
 *
 * @param {ClientOptions & { projectPath: string }} options
 */
export async function createThread(options) {
  return requestJson({
    ...options,
    path: THREADS_PATH,
    method: 'POST',
    body: { projectPath: options.projectPath },
  });
}

/**
 * The id of a thread, from whatever shape `createThread` came back with.
 *
 * @param {unknown} data
 */
export function threadIdFrom(data) {
  const record = data && typeof data === 'object' ? /** @type {Record<string, unknown>} */ (data) : {};
  for (const key of ['id', 'threadId']) {
    const value = record[key];
    if (typeof value === 'string' && value) return value;
  }
  const nested = record.thread;
  if (nested && typeof nested === 'object') {
    const id = /** @type {{ id?: unknown }} */ (nested).id;
    if (typeof id === 'string' && id) return id;
  }
  return '';
}
