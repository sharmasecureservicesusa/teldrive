#!/usr/bin/env bash
# Per-boot startup for the Teldrive Cloud Agent environment.
# Brings up the local PostgreSQL 17 (pgroonga) cluster and ensures the
# application database role exists. Idempotent and safe to re-run.
set -euo pipefail

echo "==> Ensuring PostgreSQL 17 cluster is running"
if ! sudo pg_lsclusters -h 2>/dev/null | awk '$1=="17" && $2=="main" {print $4}' | grep -q online; then
  sudo pg_ctlcluster 17 main start
fi

echo "==> Waiting for PostgreSQL to accept connections"
for _ in $(seq 1 30); do
  if pg_isready -h 127.0.0.1 -p 5432 -q; then
    break
  fi
  sleep 1
done
pg_isready -h 127.0.0.1 -p 5432

echo "==> Ensuring 'teldrive' database role exists"
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='teldrive'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE ROLE teldrive WITH LOGIN SUPERUSER PASSWORD 'secret';"
fi

echo "==> PostgreSQL ready (database 'postgres', role 'teldrive'). Schema migrations run automatically on server start."
