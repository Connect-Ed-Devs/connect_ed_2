# Freebuff orchestrator contract (as observed, not as assumed)

Skinbuff is a renderer that the **real** Freebuff Desktop shell loads, so everything it
depends on belongs to someone else's program. This file records what was actually read out
of the installed build and what was actually observed on a running orchestrator, so a future
reader can tell the two apart from a guess.

## Where the facts came from

| Source | Path |
| --- | --- |
| Electron shell (main process) | `%LOCALAPPDATA%/Programs/@codebufffreebuff-desktop/resources/app.asar` → `electron/*.cjs` |
| Orchestrator server | `.../resources/orchestrator/orchestrator.js` (single Bun bundle, ~10 MB) |
| Shipped renderer | `.../resources/orchestrator/ui/` (Vite React build + 317 CSS custom properties) |
| Bundled runtime | `.../resources/bun/bun.exe` |
| App state / logs | `%APPDATA%/Freebuff/` (`theme`, `interface-zoom`, `logs/orchestrator-stderr.log`) |

The `app.asar` header is readable in place (16-byte pickle header, then `offset` per entry
relative to `16 + headerSize`), which is how the shell sources were read without extracting
anything into the installed directory.

## How the shell starts the orchestrator

From `electron/main.cjs:startOrchestrator`. A child is spawned as
`<resources>/bun/bun.exe <resources>/orchestrator/orchestrator.js`, with `cwd` set to the
orchestrator directory and these environment variables:

```
PORT                                  requested port (0 = pick a free one, dev-UI = API port)
FREEBUFF_SHELL_LIFETIME_PORT          port of the shell-lifetime server main just created
FREEBUFF_DESKTOP_STATE_PATH           isolated state path
FREEBUFF_PROFILE_LOCK_WAIT_MS         10000
FREEBUFF_APP_VERSION                  app.getVersion()
FREEBUFF_UI_DIR                       <resources>/orchestrator/ui  (packaged only)
FREEBUFF_DESKTOP_UI_ORIGIN            ONLY when FREEBUFF_DEV_UI is set → http://127.0.0.1:<uiPort>
CODEBUFF_WASM_DIR / CODEBUFF_TREE_SITTER_WASM_PATH
FREEBUFF_CDP_BRIDGE_PORT / FREEBUFF_MCP_CONSENT_PORT   (ports only)
```

`FREEBUFF_LAUNCH_ID`, `FREEBUFF_CDP_BRIDGE_TOKEN` and `FREEBUFF_MCP_CONSENT_TOKEN` are
deliberately **stripped** from the environment (`electron/launch-bootstrap.cjs`) because any
process of the same user can read a child's starting environment. Instead they arrive on the
orchestrator's **stdin as one JSON line**:

```json
{"shellLifetimeToken":"…","launchId":"…","cdpBridgeToken":"…","mcpConsentToken":"…"}
```

Readiness is announced on **stdout** as a single line (`main.cjs:beginReadiness`):

```
[orchestrator-ready] {"launchId":"…","pid":1234,"port":59594}
```

`main.cjs` ignores it unless `launchId` matches the one it minted, `pid` matches the child, and
`port` is a valid port equal to the requested one when one was requested.

## Authentication: the launch secret

The orchestrator refuses `/api/` requests that do not prove they came from the app's own
renderer. Two carriers exist for the same value, the per-launch `launchId` (a UUID):

- **Header** `x-freebuff-launch-id: <launchId>` — used by renderer `fetch` calls (the value
  reaches the page over IPC) and by the health probe.
- **Cookie** `freebuff_launch_<orchestratorPort>=<launchId>` — planted by Electron main into the
  app session, `Path=/api`, `HttpOnly`, `SameSite=Strict`, no expiry, `Secure` off for loopback.
  The comment in `orchestrator-request.cjs` is explicit that this exists for the requests a page
  **cannot** put a header on: the `/api/events` EventSource and the terminal WebSocket.

The cookie name embeds the orchestrator's port because cookies ignore ports; the value is a
secret and must never be logged, persisted, or echoed.

### Observed (live orchestrator, port 59594, launched without `FREEBUFF_DEV_UI`)

```
GET /healthz                          no header            → 401  {"error":"invalid launch id"}
GET /healthz                          x-freebuff-launch-id: deadbeef → 401 {"error":"invalid launch id"}
GET /api/threads                      no credentials       → 401  {"error":"unauthorized"}
GET /api/projects                     no credentials       → 401  {"error":"unauthorized"}
GET /api/v1/freebuff/session          no credentials       → 401  {"error":"unauthorized"}
GET /api/settings/ui                  no credentials       → 401  {"error":"unauthorized"}
GET /api/account/usage                no credentials       → 401  {"error":"unauthorized"}
GET /api/events (Accept: SSE)         no credentials       → 401  {"error":"unauthorized"}
GET /api/threads   Cookie: freebuff_launch_59594=deadbeef → 401 {"error":"unauthorized"}
```

## The origin guard, and the proof that the dev-UI seam is real

The guard runs **before** the launch check, which is visible in the response it chooses:

```
GET /api/threads                                             → 401 {"error":"unauthorized"}
GET /api/threads   Origin: http://evil.test                  → 403 {"error":"forbidden origin"}
GET /api/threads   Origin: http://127.0.0.1:59594 (its own)  → 401 {"error":"unauthorized"}
GET /api/threads   Origin: http://127.0.0.1:5174             → 403 {"error":"forbidden origin"}
```

Two things follow, and both are load-bearing for Skinbuff:

1. A foreign `Origin` is refused with **403**, while a request with **no** `Origin` is admitted
   by the origin guard by design (it then fails the launch check with 401). This is why the
   launch secret exists at all — `127.0.0.1:<port>` is one `curl` away for any local process.
2. `http://127.0.0.1:5174` was **rejected by the running instance** because that instance was
   started without `FREEBUFF_DEV_UI`, so `main.cjs` deleted `FREEBUFF_DESKTOP_UI_ORIGIN` from
   its child's environment (`env.FREEBUFF_DESKTOP_UI_ORIGIN` is set *only* under
   `if (process.env.FREEBUFF_DEV_UI)`, otherwise `delete`d). The 5174 default is therefore not
   a constant of the server — it is a consequence of how the app was launched.

That second point is the empirical confirmation of the whole approach: **the orchestrator will
admit the Skinbuff origin exactly when the shell is launched with `FREEBUFF_DEV_UI=1` and
`FREEBUFF_DESKTOP_UI_PORT` set to the port Skinbuff serves on.** Skinbuff's `scripts/attach.mjs`
does precisely that, and its proxy forwards the page's `Origin` verbatim so the forwarded value
is the one the orchestrator was told to expect.

### Dev-UI wiring, from `main.cjs`

```js
const devUi     = !!process.env.FREEBUFF_DEV_UI
const devUiPort = Number(process.env.FREEBUFF_DESKTOP_UI_PORT) || 5174
const devApiPort= Number(process.env.FREEBUFF_DESKTOP_API_PORT) || 8787
const requestedPort = devUi ? devApiPort : 0
appUrl = devUi ? `http://127.0.0.1:${devUiPort}/` : `http://127.0.0.1:${port}/`
```

So in dev-UI mode: the shipped window loads `http://127.0.0.1:5174/` (Skinbuff), the
orchestrator listens on **exactly** 8787, and the origin guard is told to admit 5174. A
hand-rolled `FREEBUFF_DEV_UI=1 electron .` is named in the source comment as a supported-but-
internal entry point.

## Route inventory (grepped from the bundle)

Reads, events, projects, settings, skills, MCP, account, ads and web surfaces, including:

```
/healthz
/api/events                        SSE, text/event-stream
/api/threads        /api/chat      /api/drafts   /api/thread-scratch
/api/projects       /api/workspace /api/workspace/bootstrap
/api/project/{files,changes,changes/diff,git-state,branches,recents,open,switch-branch,…}
/api/settings       /api/settings/ui   /api/appearance/wallpapers   /api/appearance/usage
/api/v1/freebuff/{session,session/admission,models,appearance,usage-summary,device-keys}
/api/v1/agent-runs  /api/v1/project-profile  /api/v1/docs-search  /api/v1/web-search
/api/skills  /api/skills/{search,install,create}   /api/mcp/{servers,reload}
/api/account/{usage,skills,web,paid-api}           /api/terminal
/api/diagnostics/{renderer-boot,renderer-error,renderer-health,toast}
/api/storage/  /api/search  /api/github  /api/sites  /api/gravity-index  /api/coordinator
/api/v1/ads/*  /api/ad/*  /api/web/*
```

Routing is `if (pathname === "/api/threads")`-style checks over one flat list; `POST` verbs are
attached per route (e.g. `"POST", "/api/v1/ads/prefs"`).

## What Skinbuff does with this

- Proxies the whole `/api/` prefix and `/healthz`, forwarding method, path, query, body and
  headers (notably `cookie`, `origin`, `accept`) verbatim, rewriting only `host` to the
  orchestrator's authority. Headers are forwarded rather than re-derived because the launch
  cookie, the origin the guard compares against, and the SSE `Accept` all have to arrive as the
  page sent them.
- Never mints a launch id, never reads the cookie's value, never logs it.
- Streams `text/event-stream` without buffering and without compression.
- Falls back to bundled fixtures when the orchestrator is unreachable, so the UI is useful and
  testable even when the app is closed.

## Known limits of this pinning

- **Payload shapes are not pinned.** Every read route answered `401 unauthorized` without a
  launch secret, and the secret is per-launch and deliberately unavailable to any other process
  (`HttpOnly`, and the header only travels over IPC to the app's own window). The exact JSON for
  `/api/threads`, `/api/chat` and the `/api/events` frames therefore could not be captured from
  outside the app and is **not** invented here. Skinbuff reads them defensively (see
  `src/state/board.mjs`) and the shapes are to be recorded the first time a real attached
  session is available.
- **Mutation shapes are not pinned** for the same reason. Skinbuff's first pass writes nothing
  to the orchestrator.
- **`/healthz` needs the header form**: `GET /healthz` with `x-freebuff-launch-id` answers
  `200 {"ok":true,"launchId":…,"pid":…,"port":…}` to the shell. Skinbuff uses a reachability
  probe instead: it treats *any* HTTP answer on 8787 as "an orchestrator is listening" and
  distinguishes "attached" from "demo" on that, never claiming an authenticated health check.
