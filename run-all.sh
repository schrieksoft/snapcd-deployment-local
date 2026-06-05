#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SNAPCD_LOG_DIR:-$SCRIPT_DIR/.logs}"
mkdir -p "$LOG_DIR"

pids=()
cleanup() {
  echo
  echo "Shutting down…"
  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Starting server (log: $LOG_DIR/server.log)"
"$SCRIPT_DIR/components/server/run.sh" > "$LOG_DIR/server.log" 2>&1 &
pids+=($!)

echo "Waiting for server on http://localhost:8080…"
for _ in {1..60}; do
  if curl -sf "http://localhost:8080/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "Starting runner (log: $LOG_DIR/runner.log)"
"$SCRIPT_DIR/components/runner/run.sh" > "$LOG_DIR/runner.log" 2>&1 &
pids+=($!)

echo "Starting agent (log: $LOG_DIR/agent.log)"
"$SCRIPT_DIR/components/agent/run.sh" > "$LOG_DIR/agent.log" 2>&1 &
pids+=($!)

echo
echo "All components running. Tail logs with:"
echo "  tail -f $LOG_DIR/server.log"
echo "  tail -f $LOG_DIR/runner.log"
echo "  tail -f $LOG_DIR/agent.log"
echo
echo "Press Ctrl-C to stop everything."

wait
