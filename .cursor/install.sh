#!/usr/bin/env bash
# Idempotent repository bootstrap for the Teldrive Cloud Agent environment.
# Runs after the repo is checked out. System packages (Go, PostgreSQL 17 +
# pgroonga, make, unzip, curl) are provided by the base environment.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Downloading Go module dependencies"
go mod download

# The Makefile's `frontend` target pins the teldrive-ui "v1" release asset,
# which upstream now returns 404 for. Fetch the current prebuilt UI bundle so
# the Go binary can embed it (ui/ui.go uses //go:embed all:dist).
#
# A copy is cached outside /workspace (persisted in the environment base) so
# builds do not depend on GitHub's release CDN being reachable at install time.
UI_ASSET_URL="https://github.com/tgdrive/teldrive-ui/releases/download/latest/teldrive-ui.zip"
UI_CACHE="/opt/teldrive/teldrive-ui.zip"
tmp_zip="$(mktemp --suffix=.zip)"
trap 'rm -f "$tmp_zip"' EXIT

ui_zip=""
echo "==> Fetching prebuilt UI bundle"
if curl -fL --retry 5 --retry-delay 3 --connect-timeout 20 -o "$tmp_zip" "$UI_ASSET_URL"; then
  ui_zip="$tmp_zip"
  # Refresh the cache best-effort (may need sudo depending on dir ownership).
  if { mkdir -p "$(dirname "$UI_CACHE")" && cp "$tmp_zip" "$UI_CACHE"; } 2>/dev/null; then
    echo "    refreshed cache at $UI_CACHE"
  elif { sudo mkdir -p "$(dirname "$UI_CACHE")" && sudo cp "$tmp_zip" "$UI_CACHE"; } 2>/dev/null; then
    echo "    refreshed cache at $UI_CACHE (sudo)"
  fi
elif [ -f "$UI_CACHE" ]; then
  echo "    download failed; falling back to cached bundle at $UI_CACHE"
  ui_zip="$UI_CACHE"
else
  echo "ERROR: could not download UI bundle and no cache is present at $UI_CACHE" >&2
  exit 1
fi

rm -rf ui/dist
mkdir -p ui/dist
unzip -q -o "$ui_zip" -d ui/dist
test -f ui/dist/index.html

echo "==> Building teldrive binary"
make backend

echo "==> Install complete: $(./bin/teldrive version | tr '\n' ' ')"
