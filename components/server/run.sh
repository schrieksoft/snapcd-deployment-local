#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -x "$SCRIPT_DIR/bin/SnapCd.Server.Host" ]]; then
  echo "Server binary not found. Run $SCRIPT_DIR/install.sh first." >&2
  exit 1
fi

ln -sf "$SCRIPT_DIR/config/appsettings.json" "$SCRIPT_DIR/bin/appsettings.json"

cd "$SCRIPT_DIR/bin"
export ASPNETCORE_ENVIRONMENT="${ASPNETCORE_ENVIRONMENT:-Production}"
exec ./SnapCd.Server.Host --urls="${ASPNETCORE_URLS:-http://0.0.0.0:8080}"
