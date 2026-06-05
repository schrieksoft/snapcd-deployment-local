#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -x "$SCRIPT_DIR/bin/orchestrator/SnapCd.Agent" ]]; then
  echo "Agent binary not found. Run $SCRIPT_DIR/install.sh first." >&2
  exit 1
fi

ln -sf "$SCRIPT_DIR/config/appsettings.json" "$SCRIPT_DIR/bin/orchestrator/appsettings.json"

SIDECAR_PORT="${SIDECAR_PORT:-7001}"

SIDECAR_PID=""
cleanup() {
  if [[ -n "$SIDECAR_PID" ]]; then
    kill "$SIDECAR_PID" 2>/dev/null || true
    wait "$SIDECAR_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

SIDECAR_BIN="$SCRIPT_DIR/bin/sidecar-claude/snapcd-agent-sidecar-claude"
if [[ -x "$SIDECAR_BIN" ]]; then
  echo "Starting Claude sidecar on port $SIDECAR_PORT"
  PORT="$SIDECAR_PORT" ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" "$SIDECAR_BIN" &
  SIDECAR_PID=$!
  sleep 2
else
  echo "Claude sidecar not installed; orchestrator will fail any mission that needs it." >&2
fi

cd "$SCRIPT_DIR/bin/orchestrator"
./SnapCd.Agent
