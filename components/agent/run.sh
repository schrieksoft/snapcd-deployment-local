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
  # MCP is served at {SNAPCD_BASE_URL}/mcp. The sidecar refuses to start without it.
  PORT="$SIDECAR_PORT" \
  SNAPCD_BASE_URL="${SNAPCD_BASE_URL:-http://localhost:5000}" \
  CLAUDE_CODE_OAUTH_TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}" \
  ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
  GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
    "$SIDECAR_BIN" &
  SIDECAR_PID=$!
  sleep 2
else
  echo "Claude sidecar not installed; orchestrator will fail any mission that needs it." >&2
fi

cd "$SCRIPT_DIR/bin/orchestrator"
./SnapCd.Agent
