#!/bin/sh
set -eu
APP_ROOT="${APP_ROOT:-$HOME/abcd}"
APP_BIN="$APP_ROOT/abcd"
APP_DATA="$APP_ROOT/data"
PORT_FILE="$APP_ROOT/port"
LOG="$APP_ROOT/keepalive.log"
PORT="${ABCD_PORT:-}"
[ -z "$PORT" ] && [ -f "$PORT_FILE" ] && PORT="$(cat "$PORT_FILE")"
[ -z "$PORT" ] && PORT="6324"
ts(){ date '+%F %T'; }
if [ ! -x "$APP_BIN" ]; then
  echo "$(ts) missing binary: $APP_BIN" >> "$LOG"
  exit 1
fi
if ! pgrep -f "$APP_BIN server --data $APP_DATA" >/dev/null 2>&1; then
  echo "$(ts) process down, starting" >> "$LOG"
  nohup "$APP_BIN" server --data "$APP_DATA" >/dev/null 2>&1 &
  sleep 3
fi
code="$(curl -L -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" || true)"
if [ "$code" != "200" ]; then
  echo "$(ts) unhealthy: $code, restarting" >> "$LOG"
  pkill -f "$APP_BIN server --data $APP_DATA" >/dev/null 2>&1 || true
  nohup "$APP_BIN" server --data "$APP_DATA" >/dev/null 2>&1 &
else
  echo "$(ts) healthy: $code" >> "$LOG"
fi
