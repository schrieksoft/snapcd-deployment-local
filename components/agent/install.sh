#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/versions.env"
VERSION="${VERSION:-$SNAPCD_VERSION}"

rm -rf "$SCRIPT_DIR/bin"
mkdir -p "$SCRIPT_DIR/bin/orchestrator" "$SCRIPT_DIR/bin/sidecar-claude"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Orchestrator
ORCH_URL="https://github.com/schrieksoft/snapcd/releases/download/$VERSION/snapcd-agent-$VERSION.zip"
echo "Installing snapcd-agent $VERSION from $ORCH_URL"
curl -fL -o "$tmpdir/snapcd-agent.zip" "$ORCH_URL"
unzip -q "$tmpdir/snapcd-agent.zip" -d "$SCRIPT_DIR/bin/orchestrator"
chmod +x "$SCRIPT_DIR/bin/orchestrator/SnapCd.Agent"

# Claude sidecar.
# NOTE: snapcd-agent-sidecar-claude is not yet published by the upstream Snap CD release pipeline.
# Tracked in the ai-agent-plan under "27.2 Publish the snapcd-agent-sidecar-claude container image"
# (and the equivalent release-artifact step). Until that lands, the curl below will 404 — install
# the sidecar from source (see the README's Agent section) or skip the sidecar bring-up.
SIDECAR_URL="https://github.com/schrieksoft/snapcd/releases/download/$VERSION/snapcd-agent-sidecar-claude-$VERSION.zip"
echo "Installing snapcd-agent-sidecar-claude $VERSION from $SIDECAR_URL"
if curl -fL -o "$tmpdir/snapcd-agent-sidecar-claude.zip" "$SIDECAR_URL"; then
  unzip -q "$tmpdir/snapcd-agent-sidecar-claude.zip" -d "$SCRIPT_DIR/bin/sidecar-claude"
  chmod +x "$SCRIPT_DIR/bin/sidecar-claude/snapcd-agent-sidecar-claude" || true
  echo "Installed sidecar at $SCRIPT_DIR/bin/sidecar-claude/"
else
  echo
  echo "WARNING: snapcd-agent-sidecar-claude release artifact not available yet."
  echo "         Install the sidecar from source — see the Agent section of the repo README." >&2
fi

echo "Installed orchestrator at $SCRIPT_DIR/bin/orchestrator/SnapCd.Agent"
