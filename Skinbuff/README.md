# Skinbuff

**A cto.new-style workspace for Freebuff Desktop.** Same agents, same orchestrator, a
renderer built around the work instead of the terminal.

The badge in the header says exactly one of two things, and it is never wrong: `live` when
the panel data came back from the real Freebuff orchestrator, `demo data` when it did not.

## What it is

Freebuff Desktop's own window is an Electron shell that loads a renderer from a loopback
URL and hands it a local HTTP + SSE API. That shell ships an internal dev-UI seam — with
`FREEBUFF_DEV_UI` set it loads *your* renderer on port 5174 while the real orchestrator
serves the API on 8787. Skinbuff is a renderer written for that seam.

It is not a mock and not a fork. It never modifies anything under the app's install
directory, and every byte of workspace data comes from the app you already have. When the
app is closed, the same UI renders a deterministic demo workspace so it can be used,
reviewed and tested without it.

Surfaces: the **chat** with the Lead, a **board** of agent tasks across four columns, the
**team** roster with per-agent activity, and an **approvals** queue for the decisions that
are waiting on you. Terminals and the ad surface are deliberately absent.

Both actions are real when the app is attached. A message you send becomes a real turn at
`/api/chat` and the reply in the conversation is what the agent actually returned; an
approval becomes a real decision at the app's own git-invitation route. See
[What the two actions do](#what-the-two-actions-do).

## Running it

```bash
node server/dev-server.mjs                 # standalone preview on http://127.0.0.1:5174
npm test                                   # tsx --test
npm run typecheck                          # tsc --noEmit, JS checked
```

Standalone, it serves the skin and proxies to whatever orchestrator is listening. With
nothing listening, it shows the demo workspace — the UI is the real thing either way.

## Attaching to the app

**Quit Freebuff first.** The shell is single-instance, so a second launch is handed to the
window that is already open, and that window is not pointing at the skin.

```bash
npm run attach                 # serve the skin, then start Freebuff pointed at it
```

`scripts/attach.mjs`:

1. refuses to start if the API port is in use (that means the app is already running),
2. finds `Freebuff.exe`, or takes `--app <dir>` / `FREEBUFF_DESKTOP_DIR`,
3. serves the skin on 5174 (the next free port if 5174 is taken, and the app is told which),
4. starts the app with `FREEBUFF_DEV_UI=1`, `FREEBUFF_DESKTOP_UI_PORT` and
   `FREEBUFF_DESKTOP_API_PORT` set, and
5. waits for `/healthz` and reports whether the orchestrator came up.

The app points its window at the skin and does all the work. Everything the skin asks for
under `/api/` is proxied verbatim — method, path, query, body and headers, notably the
launch cookie and the `Origin` the orchestrator's origin guard compares against.

Useful flags:

```bash
npm run attach -- --print-env          # print the launch line instead of starting the app
npm run attach -- --ui-port 6001 --api-port 6002
node scripts/start-detached.mjs        # run the skin alone, detached; prints pid and log paths
```

## Detaching

Nothing to undo. The skin is reached through environment variables on a process you
started, so detaching is:

1. **Quit Freebuff** (Cmd/Ctrl+Q).
2. **Stop the skin server** — Ctrl+C in the terminal running `npm run attach`, or stop the
   `start-detached` pid if you used that.

Reopen Freebuff normally and the shipped renderer is back, because nothing in the install
directory was ever written to: not a file, not a setting, not the theme, not a launch id.
`npm run attach` again to reattach.

## What the two actions do

Both were extracted from the shipped bundles rather than guessed, and both are pinned in
[docs/api-contract.md](docs/api-contract.md).

- **Chat** is the Vercel AI SDK's `HttpChatTransport`, so sending is `POST /api/chat` with
the body that transport builds (`{ id, messages, trigger, messageId }`, messages as
`{ id, role, parts: [{ type: 'text', text }] }`) and the reply is an AI SDK UI message
stream. Skinbuff reads the prose out of its `text-delta` chunks and puts *that* in the
conversation. It needs a thread, so it uses the one the reads returned, or creates one the
way the app's renderer does.
- **Approvals** are git invitations: `POST /api/ad/invitation/git/approve` with
`{ threadId, invitationId, token, files, identity, confirmed: true }`, or
`.../decline` with `{ threadId, invitationId }`. An approval echoes a `token` that only an
inspection returns, so Skinbuff sends the one it has and does not invent one.

The launch cookie the app's own window carries is forwarded on both, which is what
authorises the write. The consequences of that, stated plainly:

- **A refusal is never dressed up as success.** If the orchestrator answers 401 or 403, you
see that status and that message; no scripted reply is substituted for it. The same goes for
an approval with no live invitation behind it — the decision is refused and the approval is
left pending rather than quietly marked resolved.
- **Nothing is applied optimistically.** A decision is only shown as made once the server —
and therefore the app — has agreed.
- **A partial reply stays partial.** If an agent errors mid-stream, the text that arrived is
kept and the error is reported alongside it.

## Checks

```bash
npm run typecheck
npm test
```

88 tests cover the state engine, the fixtures, the orchestrator client (including the AI SDK
stream parser and the chat body), the HTTP server (static serving, the proxy's forwarding and
streaming behaviour, the write guards) and the attach launcher's argument and discovery
helpers. The proxy, the stream and both live writes are verified against a stand-in
orchestrator that records exactly what it was sent, rather than against assumptions about it.

## Layout

```
docs/api-contract.md        what was read out of the installed app, and what was observed live
server/create-server.mjs    static skin, the skin API, the SSE-safe proxy, fixture fallback
server/dev-server.mjs       the standalone preview
src/api/orchestrator.mjs    orchestrator client: health probe, reads, SSE frames
src/api/fixtures.mjs        the deterministic demo workspace
src/state/board.mjs         pure reducers: events -> tasks, roster, approvals
renderer/                   the shell, the views and the design tokens
scripts/                    attach + detached launchers
tests/                      tsx --test
```

`src/state/board.mjs` is imported by both the server and the browser, so "what a workspace
is" has one definition rather than two.

## Limits, stated plainly

- **The orchestrator's payload shapes are not pinned.** Every read route answers `401`
  without the per-launch secret, and that secret reaches only the app's own window. So
  Skinbuff reads defensively and records the real shapes the first time an attached session
  is available — see [docs/api-contract.md](docs/api-contract.md), which lists exactly what
  was observed versus what is still unknown.
- **The dev-UI seam is internal.** It is used by Freebuff's own dev workflow
  (`FREEBUFF_DESKTOP_UI_ORIGIN` defaults to 5174), but it is undocumented and could change
  in any release. The demo mode exists so a change there degrades to a useful UI rather
  than a blank window.
- **The two writes are pinned but were not observed against the real app.** Their routes and
  bodies come from the shipped bundles, and they were exercised end to end through a browser
  against a stand-in that speaks the same protocol — but a completed turn and a real
  invitation decision against a running Freebuff still need the app relaunched with
  `FREEBUFF_DEV_UI=1` in your own session. `trigger: "submit-message"` is the AI SDK's own
  literal rather than an observation of an accepted turn, and the JSON each write route returns
  is still unknown, so nothing here depends on it.
- **Replies arrive when the turn finishes, not as they stream.** The assistant's text is
  published to the skin's stream once, at the end of the turn, rather than delta by delta.
