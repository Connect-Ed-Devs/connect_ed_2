# Workspace layout

```
AIWork/
├── Connect Ed/     Flutter student companion app (tracked in git)
├── Converto/       Claude-skill converter (Electron + CLI)
├── Skinbuff/       cto.new-style renderer for Freebuff Desktop (vanilla JS + Node)
├── Wittlet/        daily word games (Next.js)
├── Deepcut/        Wittlet's "Deep End" rarity game
├── node_modules/   shared dependencies resolved by Converto
├── .agents/        Freebuff skills for this workspace
└── .freebuff/      run docs and Freebuff project metadata
```

# Converto — how to reproduce artifacts and run it

## Reproduce the uncommitted artifacts

There is nothing to copy and no install step required:

- `Converto/package.json` declares `js-yaml` and `unzipper`, and both already
  exist in the workspace-root `node_modules`, which Node resolves for the nested
  `Converto/` folder. `tsx`, `typescript` and `electron` are used from the same
  place.
- If you ever want Converto to own its dependencies, run `npm install` inside
  `Converto/`; that is optional and changes nothing else.

Regenerate the fixture artifacts (deterministic, derived from
`Converto/src/node/samples.mjs`):

```bash
node Converto/scripts/make-fixtures.mjs
```

## Run the server (browser preview)

Start it detached so it survives the shell that launched it:

```bash
node Converto/scripts/start-detached.mjs "<log-path>"
```

It prints `pid=<pid>` immediately. The server prefers port **7420** and walks
upward if that port is taken, so read the first line of the log to learn the
actual URL:

```
CONVERTO_DEV_SERVER http://127.0.0.1:7420
```

Stop it with the pid it printed:

```bash
taskkill //PID <pid> //F
```

### Why not the `Start-Process` one-liner

The Windows detach recipe
(`powershell -NoProfile -Command "(Start-Process ...).Id"`) starts the server
correctly but never returns control to the calling shell in this environment —
the command hangs until it is killed. `scripts/start-detached.mjs` uses Node's
`detached: true` + `stdio: ['ignore', logFd, errFd]` + `unref()` instead, which
returns immediately, keeps the server alive, and still gives you the pid.

## Run the desktop app

```bash
cd Converto
npx --no-install electron electron/main.cjs
```

The window loads the same local server the dev server runs, so the desktop app
and the browser preview share one API implementation. Only native file dialogs
and "reveal in file manager" go over IPC.

## Checks

```bash
cd Converto
npx --no-install tsc --noEmit
npx --no-install tsx --test "tests/**/*.test.mts"
```

## Command-line use

```bash
node Converto/bin/converto.mjs targets
node Converto/bin/converto.mjs convert --in <skill folder|.zip|.json|SKILL.md> \
  --target freebuff --target agent-skill --out <dir> --zip
node Converto/bin/converto.mjs install-freebuff --in <input> --project <project root>
node Converto/bin/converto.mjs list-freebuff --project <project root>
```

# Skinbuff — how to run it and how to attach it

Zero runtime dependencies. `tsx` and `typescript` resolve from the workspace-root
`node_modules`, exactly as Converto does, so there is no install step.

## Checks

```bash
cd Skinbuff
npx --no-install tsc --noEmit
npx --no-install tsx --test "tests/**/*.test.mts"
```

## Browser preview on its own

```bash
node Skinbuff/server/dev-server.mjs          # prefers port 5174, walks upward
node Skinbuff/scripts/start-detached.mjs "<log-path>"   # prints pid= immediately
```

The first line of the log is the machine-readable one, and is how you learn the
port that was actually bound:

```
SKINBUFF_DEV_SERVER http://127.0.0.1:5174
```

With no orchestrator listening it serves the bundled demo workspace; the header
badge says which of the two it is, and it is never wrong.

## Attaching to the installed Freebuff Desktop app

Quit Freebuff first — the shell is single-instance, so a second launch is handed
to the window that is already open and that window is not pointing at the skin.

```bash
node Skinbuff/scripts/attach.mjs            # serves the skin, then starts the app
node Skinbuff/scripts/attach.mjs --print-env  # print the launch line instead
```

It refuses to start if the API port (8787) is busy, serves the skin on 5174 (or
the next free port, which the app is told about), starts `Freebuff.exe` with
`FREEBUFF_DEV_UI=1`, `FREEBUFF_DESKTOP_UI_PORT` and `FREEBUFF_DESKTOP_API_PORT`,
then waits for `/healthz`. Detaching is quitting the app and stopping the server:
nothing under the installed app's directory is ever written to.

The orchestrator routes, the launch cookie and the origin guard are recorded in
`Skinbuff/docs/api-contract.md`, separated into what was read out of the build and
what was observed on a running instance.

# Other projects

- **Connect Ed** is a Flutter app. Its `build/` and `.dart_tool/` were removed
  when it moved out of the workspace root (they cached absolute paths), so run
  `flutter pub get` inside `Connect Ed/` before building.
- **Wittlet** and **Deepcut** each keep their own `node_modules`; run their own
  `npm` scripts from inside their folders.
