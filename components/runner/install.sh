#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/versions.env"
VERSION="${VERSION:-$SNAPCD_VERSION}"

ARTIFACT="snapcd-runner"
URL="https://github.com/schrieksoft/snapcd/releases/download/$VERSION/$ARTIFACT-$VERSION.zip"

echo "Installing $ARTIFACT $VERSION from $URL"

rm -rf "$SCRIPT_DIR/bin"
mkdir -p "$SCRIPT_DIR/bin"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

curl -fL -o "$tmpdir/$ARTIFACT.zip" "$URL"
unzip -q "$tmpdir/$ARTIFACT.zip" -d "$SCRIPT_DIR/bin"
chmod +x "$SCRIPT_DIR/bin/SnapCd.Runner"

echo "Installed at $SCRIPT_DIR/bin/SnapCd.Runner"
