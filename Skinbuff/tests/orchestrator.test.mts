import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  buildChatBody,
  CHAT_PATH,
  followEventStream,
  GIT_INVITATION,
  orchestratorBaseUrl,
  parseSseFrames,
  parseUiMessageStream,
  probeOrchestrator,
  readLiveSnapshot,
  requestJson,
  toUiMessages,
} from '../src/api/orchestrator.mjs';

/** A `fetch` that answers from a script, and records what it was asked for. */
function fakeFetch(handler: (url: URL, init?: RequestInit) => Response | Promise<Response>) {
  /** @type {URL[]} */
  const calls: URL[] = [];
  const impl = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = input instanceof URL ? input : new URL(String(input));
    calls.push(url);
    return handler(url, init);
  }) as typeof fetch;
  return { impl, calls };
}

/** @param {unknown} body @param {number} status */
function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}

function streamResponse(chunks: string[]) {
  const encoder = new TextEncoder();
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      for (const chunk of chunks) controller.enqueue(encoder.encode(chunk));
      controller.close();
    },
  });
  return new Response(stream, { status: 200, headers: { 'content-type': 'text/event-stream' } });
}

describe('orchestratorBaseUrl', () => {
  test('follows the port the shell tells the orchestrator to use', () => {
    assert.equal(orchestratorBaseUrl({ FREEBUFF_DESKTOP_API_PORT: '9123' }), 'http://127.0.0.1:9123');
    assert.equal(orchestratorBaseUrl({}), 'http://127.0.0.1:8787');
    assert.equal(orchestratorBaseUrl({ SKINBUFF_ORCHESTRATOR_URL: 'http://127.0.0.1:5/' }), 'http://127.0.0.1:5');
  });
});

describe('parseSseFrames', () => {
  test('reads data, event and id fields, and joins repeated data lines', () => {
    const frames = parseSseFrames('event: task\ndata: one\ndata: two\nid: 7\n\n');
    assert.deepEqual(frames, [{ id: '7', event: 'task', data: 'one\ntwo' }]);
  });

  test('handles CRLF, comments and multi-frame payloads', () => {
    const frames = parseSseFrames(': ping\r\n\r\ndata: a\r\n\r\ndata: b\r\n\r\n');
    assert.deepEqual(
      frames.map((frame) => frame.data),
      ['a', 'b'],
    );
  });

  test('treats a lone field as a field with no value, and skips blank input', () => {
    assert.deepEqual(parseSseFrames('data\n\n'), [{ id: null, event: null, data: '' }]);
    assert.deepEqual(parseSseFrames('\n\n\n'), []);
    assert.deepEqual(parseSseFrames(''), []);
  });

  test('keeps a value that itself contains a colon', () => {
    assert.equal(parseSseFrames('data: {"a":1}\n\n')[0]!.data, '{"a":1}');
  });
});

describe('probeOrchestrator', () => {
  test('a 401 counts as reachable: it proves a Freebuff orchestrator answered', async () => {
    const { impl } = fakeFetch(() => jsonResponse({ error: 'invalid launch id' }, 401));
    const result = await probeOrchestrator({ baseUrl: 'http://127.0.0.1:1', fetchImpl: impl });
    assert.equal(result.reachable, true);
    assert.equal(result.status, 401);
  });

  test('a refused connection is not reachable, and says why', async () => {
    // Node puts the reason in a `code` on the thrown error, not in its message.
    const error = Object.assign(new Error('fetch failed'), { code: 'ECONNREFUSED' });
    const { impl } = fakeFetch(() => {
      throw error;
    });
    const result = await probeOrchestrator({ baseUrl: 'http://127.0.0.1:1', fetchImpl: impl });
    assert.equal(result.reachable, false);
    assert.match(String(result.error), /ECONNREFUSED/);
  });

  test('probes /healthz', async () => {
    const { impl, calls } = fakeFetch(() => jsonResponse({ ok: true }));
    await probeOrchestrator({ baseUrl: 'http://127.0.0.1:9', fetchImpl: impl });
    assert.equal(calls[0]!.pathname, '/healthz');
  });
});

describe('requestJson', () => {
  test('returns parsed data on success', async () => {
    const { impl } = fakeFetch(() => jsonResponse({ threads: [1, 2] }));
    const result = await requestJson({ baseUrl: 'http://127.0.0.1:9', path: '/api/threads', fetchImpl: impl });
    assert.equal(result.ok, true);
    assert.deepEqual(result.data, { threads: [1, 2] });
  });

  test('reports a non-JSON body as null data rather than throwing', async () => {
    const { impl } = fakeFetch(() => new Response('not json', { status: 200 }));
    const result = await requestJson({ baseUrl: 'http://127.0.0.1:9', path: '/api/threads', fetchImpl: impl });
    assert.equal(result.ok, true);
    assert.equal(result.data, null);
  });

  test('a transport failure is a returned error, not an exception', async () => {
    const { impl } = fakeFetch(() => {
      throw new Error('socket hang up');
    });
    const result = await requestJson({ baseUrl: 'http://127.0.0.1:9', path: '/api/threads', fetchImpl: impl });
    assert.deepEqual({ ok: result.ok, status: result.status, data: result.data }, { ok: false, status: null, data: null });
    assert.match(String(result.error), /socket hang up/);
  });
});

describe('readLiveSnapshot', () => {
  test('returns null when the reads are refused, which is the unauthenticated case', async () => {
    const { impl } = fakeFetch(() => jsonResponse({ error: 'unauthorized' }, 401));
    const live = await readLiveSnapshot({ baseUrl: 'http://127.0.0.1:9', fetchImpl: impl });
    assert.equal(live, null);
  });

  test('returns a snapshot from the readable routes, without inventing panels', async () => {
    const { impl } = fakeFetch((url) => {
      if (url.pathname === '/api/threads') return jsonResponse({ threads: [{ id: 'c1' }, { id: 'c2' }] });
      if (url.pathname === '/api/projects') return jsonResponse({ projects: [{ name: 'Skinbuff', path: 'p' }] });
      return jsonResponse({ branch: 'main' });
    });
    const live = await readLiveSnapshot({ baseUrl: 'http://127.0.0.1:9', fetchImpl: impl });
    assert.ok(live);
    assert.equal(live!.workspace.project, 'p');
    assert.equal(live!.workspace.branch, 'main');
    assert.deepEqual(live!.tasks, []);
    assert.equal(live!.activity.length, 1);
    assert.match(live!.activity[0]!.text, /1 project\(s\), 2 thread\(s\)/);
  });

  test('accepts a bare array, a `data` wrapper and an `items` list', async () => {
    const { impl } = fakeFetch((url) => {
      if (url.pathname === '/api/threads') return jsonResponse([{ id: 'a' }]);
      if (url.pathname === '/api/projects') return jsonResponse({ data: [{ name: 'via data' }] });
      return jsonResponse({});
    });
    const live = await readLiveSnapshot({ baseUrl: 'http://127.0.0.1:9', fetchImpl: impl });
    assert.ok(live);
  });

  test('refuses to call a partly-refused read a success', async () => {
    const { impl } = fakeFetch((url) =>
      url.pathname === '/api/threads' ? jsonResponse({ threads: [] }) : jsonResponse({ error: 'unauthorized' }, 401),
    );
    assert.equal(await readLiveSnapshot({ baseUrl: 'http://127.0.0.1:9', fetchImpl: impl }), null);
  });
});

describe('followEventStream', () => {
  test('delivers frames in order', async () => {
    const { impl } = fakeFetch(() => streamResponse(['data: one\n\n', 'data: two\n\n']));
    /** @type {string[]} */
    const seen: string[] = [];
    await followEventStream({
      baseUrl: 'http://127.0.0.1:9',
      path: '/api/events',
      fetchImpl: impl,
      signal: new AbortController().signal,
      onFrame: (frame) => seen.push(frame.data),
    });
    assert.deepEqual(seen, ['one', 'two']);
  });

  test('reassembles a frame split across two reads', async () => {
    const { impl } = fakeFetch(() => streamResponse(['data: spl', 'it\n\n']));
    /** @type {string[]} */
    const seen: string[] = [];
    await followEventStream({
      baseUrl: 'http://127.0.0.1:9',
      path: '/api/events',
      fetchImpl: impl,
      signal: new AbortController().signal,
      onFrame: (frame) => seen.push(frame.data),
    });
    assert.deepEqual(seen, ['split']);
  });

  test('flushes a final frame the server closed without a blank line', async () => {
    const { impl } = fakeFetch(() => streamResponse(['data: one\n\n', 'data: trailing']));
    /** @type {string[]} */
    const seen: string[] = [];
    await followEventStream({
      baseUrl: 'http://127.0.0.1:9',
      path: '/api/events',
      fetchImpl: impl,
      signal: new AbortController().signal,
      onFrame: (frame) => seen.push(frame.data),
    });
    assert.deepEqual(seen, ['one', 'trailing']);
  });

  test('throws when the stream is refused, so the caller can say so', async () => {
    const { impl } = fakeFetch(() => jsonResponse({ error: 'unauthorized' }, 401));
    await assert.rejects(
      () =>
        followEventStream({
          baseUrl: 'http://127.0.0.1:9',
          path: '/api/events',
          fetchImpl: impl,
          signal: new AbortController().signal,
          onFrame: () => {},
        }),
      /401/,
    );
  });
});

describe('the chat body the AI SDK would send', () => {
  test('maps the skin roles onto the protocol and keeps one text part per message', () => {
    const messages = toUiMessages([
      { id: 'm1', role: 'user', text: 'mark the class' },
      { id: 'm2', role: 'lead', text: 'on it' },
      { id: 'm3', role: 'agent', text: 'done' },
      { id: 'm4', role: 'system', text: 'attached' },
      { id: 'm5', role: 'user', text: '   ' },
    ]);
    assert.deepEqual(
      messages.map((message) => [message.id, message.role]),
      [
        ['m1', 'user'],
        ['m2', 'assistant'],
        ['m3', 'assistant'],
        ['m4', 'system'],
      ],
      'the Lead and the agents are both the assistant, and an empty message is dropped',
    );
    assert.deepEqual(messages[0]!.parts, [{ type: 'text', text: 'mark the class' }]);
  });

  test('serialises as { id, messages, trigger, messageId } exactly as the transport builds it', () => {
    const body = buildChatBody({
      threadId: 'th-1',
      messages: [{ id: 'local-1', role: 'user', text: 'hi' }],
      trigger: 'submit-message',
      messageId: 'local-1',
    });
    assert.deepEqual(JSON.parse(JSON.stringify(body)), {
      id: 'th-1',
      messages: [{ id: 'local-1', role: 'user', parts: [{ type: 'text', text: 'hi' }] }],
      trigger: 'submit-message',
      messageId: 'local-1',
    });

    // The transport assigns trigger/messageId unconditionally and JSON.stringify drops
    // undefined, so a send without them must not carry nulls.
    const plain = JSON.stringify(buildChatBody({ threadId: 'th-1', messages: [] }));
    assert.equal(plain, '{"id":"th-1","messages":[]}');
  });

  test('the pinned routes are the ones the shipped renderer calls', () => {
    assert.equal(CHAT_PATH, '/api/chat');
    assert.deepEqual(GIT_INVITATION, {
      inspect: '/api/ad/invitation/git/inspect',
      approve: '/api/ad/invitation/git/approve',
      decline: '/api/ad/invitation/git/decline',
    });
  });
});

describe('parseUiMessageStream', () => {
  /** The frame layout `JsonToSseTransformStream` writes. */
  const part = (value: unknown) => `data: ${JSON.stringify(value)}\n\n`;

  test('concatenates text-delta chunks and sees the sentinel', () => {
    const stream =
      part({ type: 'start' }) +
      part({ type: 'text-start', id: 't1' }) +
      part({ type: 'text-delta', id: 't1', delta: 'Ship' }) +
      part({ type: 'text-delta', id: 't1', delta: ' it.' }) +
      part({ type: 'text-end', id: 't1' }) +
      part({ type: 'finish' }) +
      'data: [DONE]\n\n';
    assert.deepEqual(parseUiMessageStream(stream), { text: 'Ship it.', error: null, finished: true });
  });

  test('accepts the model-stream text field too, because both shapes exist in the bundle', () => {
    const stream = part({ type: 'text-delta', text: 'from the model stream' }) + 'data: [DONE]\n\n';
    assert.equal(parseUiMessageStream(stream).text, 'from the model stream');
  });

  test('reports an error part without inventing text, and ignores unknown chunks', () => {
    const stream =
      part({ type: 'text-delta', id: 't1', delta: 'partial' }) +
      part({ type: 'some-future-chunk', whatever: true }) +
      part({ type: 'error', errorText: 'model refused' }) +
      'data: [DONE]\n\n';
    assert.deepEqual(parseUiMessageStream(stream), { text: 'partial', error: 'model refused', finished: true });
  });

  test('survives a partial or malformed stream instead of throwing', () => {
    for (const input of ['', 'data: {"type":"text-delta","id":"t1"', 'data: not json\n\n', ': comment\n\n']) {
      const result = parseUiMessageStream(input);
      assert.equal(typeof result.text, 'string');
      assert.equal(result.finished, false);
    }
  });
});
