#!/usr/bin/env bash
# One-command demo launcher: API bridge + React dashboard, stopped on Ctrl+C.
#
#   ./demo.sh              # start both, Ctrl+C to stop
#   API_PORT=9000 ./demo.sh        # override ports
#   ./demo.sh --logs       # tail both log streams (Ctrl+C still stops everything)
#   ./demo.sh --refresh    # force a fresh pipeline run (spends Gemini calls)
#
# Restarts reuse the snapshot cache (.demo-logs/bridge-snapshot.json), so
# a warm start costs zero Gemini calls unless --refresh is passed.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_PORT="${API_PORT:-8000}"
UI_PORT="${UI_PORT:-5173}"
LOG_DIR="$ROOT/.demo-logs"
TAIL_LOGS="0"
REFRESH="0"
for arg in "$@"; do
  case "$arg" in
    --logs) TAIL_LOGS="1" ;;
    --refresh) REFRESH="1" ;;
  esac
done
if [ "$REFRESH" = "1" ]; then
  export SDOC_SNAPSHOT="refresh"
fi

mkdir -p "$LOG_DIR"
API_PID=""
UI_PID=""

log() { printf '\033[1;36m[demo]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[demo]\033[0m %s\n' "$*" >&2; }

# --- Platform helpers ------------------------------------------------------
is_windows() { [[ "$(uname -s)" == *NT* || "$(uname -s)" == *MINGW* || "$(uname -s)" == *MSYS* ]]; }

# Fake/refresh the readiness probe result: 0 = something answers on :port.
probe() { curl -s -o /dev/null --max-time 1 "http://localhost:$1/" 2>/dev/null; }
port_in_use() { probe "$1"; }

# Windows cleanup: MSYS `$!` PIDs are NOT Windows PIDs, so `taskkill` needs the
# real listener PIDs straight from netstat instead.
release_port() {
  local port="$1" pids pid
  pids="$(netstat -ano 2>/dev/null | awk -v p=":$port" '$0 ~ (p "[ \t]") && tolower($0) ~ /listening/ {print $NF}' | sort -u)"
  for pid in $pids; do taskkill //F //T //PID "$pid" >/dev/null 2>&1 || true; done
}

kill_tree() {
  local pid="$1"
  [ -z "$pid" ] && return 0
  if is_windows; then
    kill "$pid" 2>/dev/null || true
    return 0
  fi
  local kids
  kids="$(ps -ef 2>/dev/null | awk -v p="$pid" '$3==p {print $2}' || true)"
  for k in $kids; do kill_tree "$k"; done
  kill "$pid" 2>/dev/null || true
}

# Give short taskskill/signal propagation a moment; then re-verify the ports.
verify_released() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    local busy=""
    if is_windows; then
      busy="$(netstat -ano 2>/dev/null | grep -E ":$API_PORT[ ]|:$UI_PORT[ ]" | grep -i LISTENING || true)"
    fi
    [ -z "$busy" ] && return 0
    release_port "$API_PORT"; release_port "$UI_PORT"
    sleep 1
  done
  err "ports $API_PORT/$UI_PORT still not released — force-close any leftover terminal windows"
}

cleanup() {
  log "stopping…"
  if is_windows; then
    kill "$API_PID" 2>/dev/null || true
    kill "$UI_PID" 2>/dev/null || true
    release_port "$API_PORT"; release_port "$UI_PORT"
    verify_released
  else
    kill_tree "$API_PID"; kill_tree "$UI_PID"
  fi
  wait 2>/dev/null || true
  log "done."
  exit 0
}
trap cleanup INT TERM

# --- Preflight -------------------------------------------------------------
[ "$API_PORT" != "$UI_PORT" ] || { err "API_PORT and UI_PORT must differ"; exit 1; }
if port_in_use "$API_PORT"; then err "port $API_PORT already in use — set API_PORT (or stop the process)" ; exit 1; fi
if port_in_use "$UI_PORT";  then err "port $UI_PORT already in use — set UI_PORT (or stop the process)"; exit 1; fi

if [ ! -d "$ROOT/ui/node_modules" ]; then
  log "installing ui deps (first run)…"
  (cd "$ROOT/ui" && npm install) || { err "npm install failed"; exit 1; }
fi

# --- Boot ------------------------------------------------------------------
if [ "$REFRESH" = "1" ]; then
  log "starting API bridge on :$API_PORT (forced fresh pipeline run)…"
else
  log "starting API bridge on :$API_PORT (snapshot cache; --refresh forces a re-run)…"
fi
(cd "$ROOT" && exec uv run uvicorn api.app:app --port "$API_PORT" --host 127.0.0.1) >"$LOG_DIR/api.log" 2>&1 &
API_PID=$!

log "starting dashboard on :$UI_PORT…"
(cd "$ROOT/ui" && exec npm run dev -- --strictPort --port "$UI_PORT") >"$LOG_DIR/ui.log" 2>&1 &
UI_PID=$!

wait_http() {
  local url="$1" name="$2" n="$3" i
  for i in $(seq 1 "$n"); do
    if curl -s -o /dev/null --max-time 1 "$url" 2>/dev/null; then return 0; fi
    sleep 1
  done
  err "$name did not come up at $url in ${n}s — logs in $LOG_DIR"
  return 1
}

log "waiting for services…"
wait_http "http://localhost:$API_PORT/api/health" "api bridge" 60 || { cleanup; exit 1; }
wait_http "http://localhost:$UI_PORT/"            "dashboard"   60 || { cleanup; exit 1; }

log "ready!"
printf '  \033[1;32mDashboard:\033[0m http://localhost:%s\n' "$UI_PORT"
printf '  \033[1;32mBridge:   \033[0m http://localhost:%s/api/health\n' "$API_PORT"
log "press Ctrl+C to stop both."

if [ "$TAIL_LOGS" = "1" ]; then
  log "tailing logs (Ctrl+C to stop) — files: $LOG_DIR/api.log, $LOG_DIR/ui.log"
  tail -f "$LOG_DIR/api.log" "$LOG_DIR/ui.log"
  cleanup
else
  wait -n "$API_PID" "$UI_PID" 2>/dev/null || true
  cleanup
fi