#!/usr/bin/env bash
# Runs the full-app web preview with the dev CORS proxy wired in, so a real
# school calendar feed can actually be imported from the browser.
#
#   bash tool/dev/run_web_preview.sh
#
# Ctrl-C stops both processes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PORT="${WEB_PORT:-8099}"
PROXY_PORT="${PROXY_PORT:-8124}"
FLUTTER="${FLUTTER:-flutter}"

cleanup() {
  [[ -n "${PROXY_PID:-}" ]] && kill "$PROXY_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

node tool/dev/cors_proxy.js "$PROXY_PORT" &
PROXY_PID=$!
echo "proxy pid $PROXY_PID"

# A previous run can leave build/flutter_assets locked.
rm -rf build

"$FLUTTER" run \
  -d web-server \
  --web-hostname=127.0.0.1 \
  --web-port="$PORT" \
  -t lib/dev/app_preview.dart \
  --dart-define=FEED_PROXY="http://127.0.0.1:${PROXY_PORT}/?url="
