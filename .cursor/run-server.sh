#!/usr/bin/env bash
# Runs the Teldrive backend for local development.
#
# Configuration is resolved from environment variables (set them as Cloud Agent
# secrets for real usage) with sensible development fallbacks so the server
# always boots and serves the UI + API:
#   TELDRIVE_DB_DATA_SOURCE  Postgres DSN      (default: local dev cluster)
#   TELDRIVE_JWT_SECRET      JWT signing key   (default: generated & cached)
#   TELDRIVE_TG_APP_ID       Telegram app id   (default: placeholder)
#   TELDRIVE_TG_APP_HASH     Telegram app hash (default: placeholder)
#
# The Telegram client connects lazily (only during an actual login), so
# placeholder credentials are enough to run migrations, serve the UI, and
# exercise the API. Provide real values from https://my.telegram.org to log in.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CONF_DIR="$HOME/.teldrive"
mkdir -p "$CONF_DIR"

# Persist a generated JWT secret across restarts unless one is supplied.
jwt_file="$CONF_DIR/jwt-secret"
if [ -n "${TELDRIVE_JWT_SECRET:-}" ]; then
  jwt_secret="$TELDRIVE_JWT_SECRET"
elif [ -f "$jwt_file" ]; then
  jwt_secret="$(cat "$jwt_file")"
else
  jwt_secret="$(openssl rand -hex 64)"
  printf '%s' "$jwt_secret" > "$jwt_file"
fi

dsn="${TELDRIVE_DB_DATA_SOURCE:-postgres://teldrive:secret@127.0.0.1:5432/postgres}"
app_id="${TELDRIVE_TG_APP_ID:-1234567}"
app_hash="${TELDRIVE_TG_APP_HASH:-0123456789abcdef0123456789abcdef}"
port="${TELDRIVE_SERVER_PORT:-8080}"

if [ ! -x ./bin/teldrive ]; then
  echo "bin/teldrive not found; run .cursor/install.sh first" >&2
  exit 1
fi

echo "==> Starting teldrive on http://localhost:${port}"
exec ./bin/teldrive run \
  --db-data-source "$dsn" \
  --jwt-secret "$jwt_secret" \
  --tg-app-id "$app_id" \
  --tg-app-hash "$app_hash" \
  --tg-session-file "$CONF_DIR/session.db" \
  --server-port "$port" \
  --log-development
