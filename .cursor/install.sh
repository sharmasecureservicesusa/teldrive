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
# which upstream now returns 404 for. Fetch the current prebuilt UI bundle
# directly so the Go binary can embed it (ui/ui.go uses //go:embed all:dist).
UI_ASSET_URL="https://github.com/tgdrive/teldrive-ui/releases/download/latest/teldrive-ui.zip"
echo "==> Fetching prebuilt UI bundle"
tmp_zip="$(mktemp --suffix=.zip)"
trap 'rm -f "$tmp_zip"' EXIT
curl -fL --retry 3 --retry-delay 2 -o "$tmp_zip" "$UI_ASSET_URL"
rm -rf ui/dist
mkdir -p ui/dist
unzip -q -o "$tmp_zip" -d ui/dist
test -f ui/dist/index.html

echo "==> Building teldrive binary"
make backend

echo "==> Install complete: $(./bin/teldrive version | tr '\n' ' ')"
