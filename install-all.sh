#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/components/server/install.sh"
"$SCRIPT_DIR/components/runner/install.sh"
"$SCRIPT_DIR/components/agent/install.sh"

echo
echo "All components installed. See README.md for the run sequence."
