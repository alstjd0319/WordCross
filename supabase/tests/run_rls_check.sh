#!/usr/bin/env bash
# Docker 로 빈 Postgres 를 띄워 migration 을 적용하고 RLS·RPC 동작을 확인한다.
# Supabase CLI 없이도 돌릴 수 있는 가벼운 검사. 사용: bash supabase/tests/run_rls_check.sh
set -euo pipefail
cd "$(dirname "$0")/.."
docker rm -f wc-rls-check >/dev/null 2>&1 || true
docker run -d --name wc-rls-check -e POSTGRES_PASSWORD=pw postgres:17-alpine >/dev/null
trap 'docker rm -f wc-rls-check >/dev/null' EXIT
until docker exec wc-rls-check pg_isready -U postgres -q; do sleep 1; done; sleep 2
psql_() { docker exec -i wc-rls-check psql -U postgres -q "$@"; }
psql_ -v ON_ERROR_STOP=1 < tests/00_supabase_stub.sql
for f in migrations/*.sql; do echo ">> $f"; psql_ -v ON_ERROR_STOP=1 < "$f"; done
psql_ < tests/rls_check.sql 2>&1
