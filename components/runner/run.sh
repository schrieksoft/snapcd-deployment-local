#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -x "$SCRIPT_DIR/bin/SnapCd.Runner" ]]; then
  echo "Runner binary not found. Run $SCRIPT_DIR/install.sh first." >&2
  exit 1
fi

ln -sf "$SCRIPT_DIR/config/appsettings.json" "$SCRIPT_DIR/bin/appsettings.json"

mkdir -p "$SCRIPT_DIR/runnerdata"

# Override paths to point at this repo's directories rather than what's baked into the config.
export WorkingDirectory__WorkingDirectory="$SCRIPT_DIR/runnerdata"
export WorkingDirectory__TempDirectory="$SCRIPT_DIR/runnerdata/.temp"
export HooksPreapproval__PreapprovedHooksDirectory="$SCRIPT_DIR/preapproved-hooks"

cd "$SCRIPT_DIR/bin"
exec ./SnapCd.Runner --urls="${SNAPCD_RUNNER_URLS:-http://0.0.0.0:5001}"
