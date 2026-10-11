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

## Checks

```bash
npm run typecheck
npm test
```

68 tests cover the state engine, the fixtures, the orchestrator client, the HTTP server
(static serving, the proxy's forwarding and streaming behaviour, the write guards) and the
attach launcher's argument and discovery helpers. The proxy and stream behaviour is
verified against a stand-in orchestrator that records exactly what it was sent, rather
than against assumptions about it.

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
- **The skin writes nothing to the orchestrator.** Reads and the event stream only; the
  chat and approval actions are journaled locally and answered by the demo.
