/**
 * The two writes, against a stand-in orchestrator.
 *
 * These are the tests that matter most for this feature, because the whole point of it is
 * that Skinbuff now talks to routes it does not own. So they assert three things each time:
 * the request goes to the *pinned* route with the *pinned* body, the page's own launch
 * cookie rides along, and a refusal is reported as a refusal rather than turned into a
 * scripted reply.
 */

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
 * A stand-in orchestrator that records exactly what it was sent.
 *
 * @param {(req: http.IncomingMessage, res: http.ServerResponse, recorded: Recorded) => unknown} handler
 */
async function startFakeOrchestrator(
  handler: (req: http.IncomingMessage, res: http.ServerResponse, recorded: Recorded) => unknown,
) {
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

/** @param {string} orchestratorUrl */
async function startSkinbuff(orchestratorUrl: string) {
  const skinbuff = createSkinbuffServer({ orchestratorUrl });
  const { url, port } = await skinbuff.listen(0);
  return { url, port, close: () => skinbuff.close() };
}

/** The frame layout the orchestrator's `JsonToSseTransformStream` writes. */
function part(value: unknown) {
  return `data: ${JSON.stringify(value)}\n\n`;
}

/** A reply stream with two text deltas, exactly as `createUIMessageStreamResponse` writes it. */
function writeReplyStream(res: http.ServerResponse, deltas: string[]) {
  res.writeHead(200, {
    'content-type': 'text/event-stream',
    'cache-control': 'no-cache',
    'x-vercel-ai-ui-message-stream': 'v1',
  });
  res.write(part({ type: 'start' }));
  res.write(part({ type: 'text-start', id: 't1' }));
  for (const delta of deltas) res.write(part({ type: 'text-delta', id: 't1', delta }));
  res.write(part({ type: 'text-end', id: 't1' }));
  res.write(part({ type: 'finish' }));
  res.write('data: [DONE]\n\n');
  res.end();
}

/**
 * An orchestrator that authorises the reads, so the skin resolves to live mode.
 *
 * @param {(res: http.ServerResponse, recorded: Recorded) => void} [onChat]
 */
async function startLiveOrchestrator(onChat: (res: http.ServerResponse, recorded: Recorded) => void = (res) => {
  writeReplyStream(res, ['Ship', ' it.']);
}) {
  return startFakeOrchestrator((req, res, recorded) => {
    // The health route requires the launch header even for the shell, so a 401 here is what
    // a listening orchestrator really answers, and it is still "reachable".
    if (req.url === '/healthz') return send(res, 401, { error: 'invalid launch id' });
    if (req.url === '/api/threads') return send(res, 200, { threads: [{ id: 'th-1' }] });
    if (req.url === '/api/projects') {
      return send(res, 200, { projects: [{ path: 'AIWork/Skinbuff', name: 'Skinbuff' }] });
    }
    if (req.url === '/api/v1/freebuff/session') return send(res, 200, { branch: 'Experimental-Features' });
    if (req.url === '/api/chat') return onChat(res, recorded);
    // The invitation routes answer, so a decision that reaches them is distinguishable from
    // one that never left: a 404 here would be the fake, not the skin.
    if (req.url === '/api/ad/invitation/git/approve' || req.url === '/api/ad/invitation/git/decline') {
      return send(res, 200, { ok: true, decided: req.url.endsWith('approve') ? 'approve' : 'decline' });
    }
    return send(res, 404, { error: `unexpected ${req.url}` });
  });
}

describe('live chat', () => {
  test('sends the turn to /api/chat with the transport body and journals the reply it got back', async () => {
    const orchestrator = await startLiveOrchestrator();
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const response = await fetch(`${skin.url}/api/skinbuff/chat`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          cookie: 'freebuff_launch_8787=secret',
          origin: 'http://127.0.0.1:5174',
        },
        body: JSON.stringify({ text: 'Ship it?', id: 'local-1' }),
      });
      assert.equal(response.status, 202);
      const payload = await response.json();
      assert.equal(payload.mode, 'live');
      assert.equal(payload.reply.text, 'Ship it.');

      const chat = orchestrator.requests.find((recorded) => recorded.url === '/api/chat');
      assert.ok(chat, 'the turn must be sent to /api/chat');
      assert.equal(chat.method, 'POST');
      // The body is the one HttpChatTransport builds, not the page's body.
      assert.deepEqual(JSON.parse(chat.body), {
        id: 'th-1',
        messages: [{ id: 'local-1', role: 'user', parts: [{ type: 'text', text: 'Ship it?' }] }],
        trigger: 'submit-message',
        messageId: 'local-1',
      });
      // The launch cookie and the origin the guard compares against arrive as the page sent
      // them; the host is rewritten to the orchestrator's authority.
      assert.equal(chat.headers.cookie, 'freebuff_launch_8787=secret');
      assert.equal(chat.headers.origin, 'http://127.0.0.1:5174');
      assert.equal(chat.headers.host, new URL(orchestrator.url).host);
      // A composed body must not inherit the page's declared length, or the orchestrator
      // would read it as truncated — or wait for bytes that never come.
      const declared = chat.headers['content-length'];
      if (declared !== undefined) {
        assert.equal(
          Number(declared),
          Buffer.byteLength(chat.body),
          'content-length must describe the body actually sent',
        );
      }

      const state = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      const lead = state.messages.filter((message: { role: string }) => message.role === 'lead');
      assert.equal(lead.length, 1, 'the real reply is what should be in the conversation');
      assert.equal(lead[0].text, 'Ship it.');
      assert.ok(state.messages.some((message: { id: string }) => message.id === 'local-1'));
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });

  test('a refused turn is reported as refused, and no reply is invented for it', async () => {
    const orchestrator = await startLiveOrchestrator((res) => send(res, 401, { error: 'unauthorized' }));
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const response = await fetch(`${skin.url}/api/skinbuff/chat`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ text: 'anyone there?', id: 'local-2' }),
      });
      assert.equal(response.status, 401, "the orchestrator's own status must reach the caller");
      const payload = await response.json();
      assert.equal(payload.accepted, false);
      assert.equal(payload.mode, 'live');
      assert.match(payload.error, /401/);

      const state = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      assert.deepEqual(
        state.messages.filter((message: { role: string }) => message.role === 'lead'),
        [],
        'a refused turn must not produce a scripted reply',
      );
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });

  test('an agent that errors mid-stream reports the error instead of a half reply', async () => {
    const orchestrator = await startLiveOrchestrator((res) => {
      res.writeHead(200, { 'content-type': 'text/event-stream' });
      res.write(part({ type: 'text-delta', id: 't1', delta: 'partial' }));
      res.write(part({ type: 'error', errorText: 'model refused' }));
      res.write('data: [DONE]\n\n');
      res.end();
    });
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const response = await fetch(`${skin.url}/api/skinbuff/chat`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ text: 'go', id: 'local-4' }),
      });
      assert.equal(response.status, 202);
      const payload = await response.json();
      assert.equal(payload.error, 'model refused', 'the error is surfaced, not swallowed');
      assert.equal(
        payload.reply.text,
        'partial',
        'the text that did arrive is kept, and no substitute is invented for the rest',
      );

      const state = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      const lead = state.messages.filter((message: { role: string }) => message.role === 'lead');
      assert.equal(lead.length, 1);
      assert.equal(lead[0].text, 'partial');
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });

  test('with no thread anywhere, the send is refused rather than faked', async () => {
    const orchestrator = await startFakeOrchestrator((req, res) => {
      if (req.url === '/healthz') return send(res, 401, { error: 'invalid launch id' });
      if (req.url === '/api/threads') return send(res, 200, { threads: [] });
      if (req.url === '/api/projects') return send(res, 200, { projects: [] });
      if (req.url === '/api/v1/freebuff/session') return send(res, 200, {});
      return send(res, 404, { error: 'unexpected' });
    });
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const response = await fetch(`${skin.url}/api/skinbuff/chat`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ text: 'hello', id: 'local-5' }),
      });
      assert.equal(response.status, 502);
      const payload = await response.json();
      assert.equal(payload.accepted, false);
      assert.equal(payload.mode, 'live');
      assert.match(payload.error, /no thread/i);
      assert.equal(
        orchestrator.requests.filter((recorded) => recorded.url === '/api/chat').length,
        0,
        'nothing should be sent when there is no thread to send to',
      );
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });
});

describe('live approvals', () => {
  test('a decision goes to the pinned git-invitation routes with the renderer bodies', async () => {
    const orchestrator = await startLiveOrchestrator();
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const approve = await fetch(`${skin.url}/api/skinbuff/approvals/inv-9`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', cookie: 'freebuff_launch_8787=secret' },
        body: JSON.stringify({ decision: 'allow', invitationId: 'inv-9', threadId: 'th-1', token: 'tok-1' }),
      });
      assert.equal(approve.status, 202);
      const approved = await approve.json();
      assert.equal(approved.mode, 'live');
      assert.equal(approved.decision, 'allow', "the skin's own word is kept in the answer");

      const approveRequest = orchestrator.requests.find((recorded) => recorded.url === '/api/ad/invitation/git/approve');
      assert.ok(approveRequest, 'an approval must be posted to the approve route');
      assert.equal(approveRequest.method, 'POST');
      assert.equal(approveRequest.headers.cookie, 'freebuff_launch_8787=secret');
      assert.deepEqual(JSON.parse(approveRequest.body), {
        threadId: 'th-1',
        invitationId: 'inv-9',
        token: 'tok-1',
        confirmed: true,
      });

      const decline = await fetch(`${skin.url}/api/skinbuff/approvals/inv-10`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ decision: 'deny', invitationId: 'inv-10', threadId: 'th-1' }),
      });
      assert.equal(decline.status, 202);
      assert.equal((await decline.json()).decision, 'deny');

      const declineRequest = orchestrator.requests.find((recorded) => recorded.url === '/api/ad/invitation/git/decline');
      assert.ok(declineRequest, 'a decline must be posted to the decline route');
      assert.deepEqual(JSON.parse(declineRequest.body), { threadId: 'th-1', invitationId: 'inv-10' });
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });

  test('an approval with no live invitation behind it is refused, and nothing is recorded', async () => {
    const orchestrator = await startLiveOrchestrator();
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const response = await fetch(`${skin.url}/api/skinbuff/approvals/p1`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ decision: 'allow' }),
      });
      assert.equal(response.status, 409);
      const payload = await response.json();
      assert.equal(payload.accepted, false);
      assert.equal(payload.mode, 'live');
      assert.match(payload.error, /no live invitation/i);

      assert.equal(
        orchestrator.requests.filter((recorded) => recorded.url.startsWith('/api/ad/invitation/')).length,
        0,
        'a decision with no invitation identity must not be sent anywhere',
      );
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });

  test('a refused decision is reported, and the approval is left untouched', async () => {
    const orchestrator = await startLiveOrchestrator();
    const skin = await startSkinbuff(orchestrator.url);
    try {
      const response = await fetch(`${skin.url}/api/skinbuff/approvals/inv-11`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        // No token: an approval cannot be completed without the inspection token.
        body: JSON.stringify({ decision: 'allow', invitationId: 'inv-11', threadId: 'th-1' }),
      });
      assert.equal(response.status, 202, 'the stand-in accepts it, so this checks the path not the token');

      const notAllowed = await fetch(`${skin.url}/api/skinbuff/approvals/inv-12`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', origin: 'http://evil.test' },
        body: JSON.stringify({ decision: 'allow', invitationId: 'inv-12', threadId: 'th-1' }),
      });
      assert.equal(notAllowed.status, 403, 'a cross-origin decision stays refused');
      assert.equal(
        orchestrator.requests.filter((recorded) => recorded.url.includes('inv-12')).length,
        0,
        'a refused decision must not reach the orchestrator',
      );
    } finally {
      await skin.close();
      await orchestrator.close();
    }
  });
});

describe('demo mode is unchanged by any of this', () => {
  test('both actions still answer locally, and both say they are demo', async () => {
    const skin = await startSkinbuff(NOWHERE);
    try {
      const chat = await fetch(`${skin.url}/api/skinbuff/chat`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ text: 'anything', id: 'local-3' }),
      });
      assert.equal(chat.status, 202);
      const sent = await chat.json();
      assert.equal(sent.mode, 'demo');
      assert.match(sent.reply.text, /Demo Lead here/);

      const decision = await fetch(`${skin.url}/api/skinbuff/approvals/p3`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ decision: 'deny' }),
      });
      assert.equal(decision.status, 202);
      const decided = await decision.json();
      assert.equal(decided.mode, 'demo');
      assert.match(decided.detail, /nothing was written/i);

      const state = await (await fetch(`${skin.url}/api/skinbuff/state`)).json();
      const p3 = state.approvals.find((approval: { id: string }) => approval.id === 'p3');
      assert.equal(p3.status, 'denied');
    } finally {
      await skin.close();
    }
  });
});
