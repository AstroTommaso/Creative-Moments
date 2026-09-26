#!/usr/bin/env bash
# Applies every migration to a *plain Postgres* database (with minimal auth/storage
# stand-ins for what Supabase provides) and runs the RLS regression test.
#   DB_URL=postgres://postgres:postgres@localhost:5432/postgres ./supabase/tests/run_rls.sh
# Against a real Supabase database, skip this script and run tests/rls.sql directly.
set -euo pipefail
: "${DB_URL:?set DB_URL to an EMPTY throwaway database}"
here="$(cd "$(dirname "$0")" && pwd)"
psql() { command psql "$DB_URL" -v ON_ERROR_STOP=1 -q "$@"; }
psql -f "$here/local_stub.sql"
# Supabase default privileges: API roles can reach new public objects; RLS and revokes decide.
psql -c "grant usage on schema public to authenticated, anon;
         alter default privileges in schema public grant all on tables to authenticated, anon;
         alter default privileges in schema public grant execute on functions to authenticated, anon;"
for f in "$here"/../migrations/*.sql; do echo "applying $(basename "$f")"; psql -f "$f"; done
psql -c "grant select, insert, update, delete on storage.objects to authenticated, anon;
         grant select on storage.buckets to authenticated, anon;"
psql -f "$here/rls.sql"
