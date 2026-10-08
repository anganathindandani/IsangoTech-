#!/usr/bin/env bash
# Runs the migrations and database tests against a throwaway database.
#
#   PGHOST=localhost PGPORT=5432 PGUSER=postgres supabase/tests/run.sh
#
# Connection details come from the standard PG* environment variables. The
# server's "postgres" database is only used to create and drop the test
# database "isangotech_test"; nothing else is touched.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test_db="isangotech_test"

psql_quiet() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }

psql_quiet -d postgres -c "drop database if exists ${test_db} with (force)" -c "create database ${test_db}"
trap 'psql_quiet -d postgres -c "drop database if exists ${test_db} with (force)"' EXIT

psql_quiet -d "$test_db" -f "$here/supabase_stub.sql"
for f in "$here"/../migrations/*.sql; do
  echo "migrate  $(basename "$f")"
  psql_quiet -d "$test_db" -f "$f"
done

psql_quiet -d "$test_db" -f "$here/helpers.sql"

failed=0
for f in "$here"/sql/*.sql; do
  if out=$(psql_quiet -d "$test_db" -o /dev/null -f "$f" 2>&1); then
    echo "pass     $(basename "$f")"
  else
    echo "FAIL     $(basename "$f")"
    echo "$out" | sed 's/^/         /'
    failed=1
  fi
done
exit $failed
