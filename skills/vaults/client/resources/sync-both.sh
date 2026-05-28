#!/usr/bin/env bash
# Bidirectional sync — run both push and pull in background.
# Start this once and forget about it.

DIR="$(dirname "$0")"
echo "[vault-sync] Starting bidirectional sync..."
"$DIR/sync-to-remote.sh" &
PID_PUSH=$!
"$DIR/sync-from-remote.sh" &
PID_PULL=$!

trap "kill $PID_PUSH $PID_PULL 2>/dev/null; echo '[vault-sync] stopped'; exit 0" INT TERM

echo "[vault-sync] Push PID=$PID_PUSH, Pull PID=$PID_PULL"
echo "[vault-sync] Ctrl-C to stop both"
wait
