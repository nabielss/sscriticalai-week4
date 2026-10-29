#!/usr/bin/env bash
set -euo pipefail

if [[ "${GITHUB_ACTIONS:-}" != 'true' || "${PGHOST:-}" != '127.0.0.1' || "${PGPORT:-}" != '5432' || "${PGDATABASE:-}" != 'week4' || "${PGUSER:-}" != 'ci' || "${PGPASSWORD:-}" != 'synthetic-only' ]]; then
  echo 'REFUSING: experiment requires the isolated GitHub Actions Postgres service' >&2
  exit 3
fi
case "${RUN_ARTIFACT_DIR:-}" in
  "${GITHUB_WORKSPACE:-}/artifacts/"*) ;;
  *) echo 'REFUSING: RUN_ARTIFACT_DIR must be inside this run workspace artifact directory' >&2; exit 3 ;;
esac
mkdir -p "$RUN_ARTIFACT_DIR"

psql_ci() { psql -X -v ON_ERROR_STOP=1 "$@"; }
assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" != "$expected" ]]; then
    printf 'ASSERTION_FAILED %s expected=<%s> actual=<%s>\n' "$label" "$expected" "$actual"
    exit 1
  fi
  printf 'ASSERTION_PASS %s value=<%s>\n' "$label" "$actual"
}

echo 'EXPERIMENT=03 CURRENCY_BACKFILL_INSERT_RACE'
echo 'PURPOSE=deterministically probe an old-schema insert after UPDATE snapshot begins'
echo 'SCOPE=per-statement autocommit; ADD COLUMN commits before UPDATE; no rename; not the transaction-wrapped mode'
echo 'DATA=100000 deterministic synthetic invoices; no external data'
echo 'SYNC=synthetic statement-level trigger sleeps 5s before UPDATE scans rows; not a performance measurement'
echo 'SAFETY_GUARD=environment check only; not a security boundary'
psql_ci -c 'SELECT version();'
echo "TRANSACTION_ISOLATION=$(psql_ci -Atc 'SHOW transaction_isolation;')"

seed_sql="$RUN_ARTIFACT_DIR/seed.sql"
trigger_sql="$RUN_ARTIFACT_DIR/pause-trigger.sql"
race_sql="$RUN_ARTIFACT_DIR/backfill-update.sql"
observer_sql="$RUN_ARTIFACT_DIR/update-observer.sql"
seed_log="$RUN_ARTIFACT_DIR/seed.log"
trigger_log="$RUN_ARTIFACT_DIR/pause-trigger.log"
add_log="$RUN_ARTIFACT_DIR/add-currency.log"
control_log="$RUN_ARTIFACT_DIR/pre-update-control.log"
update_log="$RUN_ARTIFACT_DIR/backfill-update.log"
observer_before_log="$RUN_ARTIFACT_DIR/update-observer-before-insert.log"
observer_after_log="$RUN_ARTIFACT_DIR/update-observer-after-insert.log"
writer_log="$RUN_ARTIFACT_DIR/concurrent-writer.log"

cat >"$seed_sql" <<'SQL'
DROP TABLE IF EXISTS invoices CASCADE;
CREATE TABLE invoices (
  id integer PRIMARY KEY,
  country text,
  amount numeric(12,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO invoices (id, country, amount, created_at)
SELECT g,
       CASE g % 3 WHEN 0 THEN 'DE' WHEN 1 THEN 'ID' ELSE 'US' END,
       (g % 100000)::numeric / 100,
       timestamptz '2020-01-01 00:00:00+00' + g * interval '1 second'
FROM generate_series(1, 100000) AS g;
SQL
cat >"$trigger_sql" <<'SQL'
DROP FUNCTION IF EXISTS pause_currency_backfill() CASCADE;
CREATE FUNCTION pause_currency_backfill() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  -- Synthetic synchronization only; use a real bounded workload for any timing or lock conclusion.
  PERFORM pg_sleep(5);
  RETURN NULL;
END
$$;
CREATE TRIGGER pause_currency_backfill_before_update
BEFORE UPDATE ON invoices
FOR EACH STATEMENT EXECUTE FUNCTION pause_currency_backfill();
SQL
cat >"$race_sql" <<'SQL'
\timing on
UPDATE invoices
SET currency = CASE country WHEN 'DE' THEN 'EUR' WHEN 'ID' THEN 'IDR' ELSE 'USD' END;
SQL
cat >"$observer_sql" <<'SQL'
SELECT clock_timestamp(), pid, state, wait_event_type, wait_event, query
FROM pg_stat_activity
WHERE application_name = 'week4-currency-race-migration'
  AND state = 'active'
  AND wait_event = 'PgSleep';
SQL

psql_ci -f "$seed_sql" >"$seed_log" 2>&1
assert_eq "$(psql_ci -Atc 'SELECT count(*) FROM invoices;')" '100000' 'seed_rows'
psql_ci -c "ALTER TABLE invoices ADD COLUMN currency text NOT NULL DEFAULT 'USD';" >"$add_log" 2>&1
psql_ci -c "INSERT INTO invoices (id, country, amount) VALUES (200001, 'DE', 10.00);" >"$control_log" 2>&1
psql_ci -f "$trigger_sql" >"$trigger_log" 2>&1

PGAPPNAME=week4-currency-race-migration timeout 60s psql -X -v ON_ERROR_STOP=1 -f "$race_sql" >"$update_log" 2>&1 &
update_pid=$!
echo "UPDATE_PROCESS_STARTED time=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ) pid=$update_pid"

observed=0
for _ in {1..100}; do
  if psql_ci -f "$observer_sql" >"$observer_before_log" 2>&1 && grep -q 'PgSleep' "$observer_before_log"; then
    observed=1
    break
  fi
  sleep 0.05
done
if [[ "$observed" != '1' ]]; then
  echo 'ASSERTION_FAILED update_pause_observed'
  cat "$observer_before_log" || true
  wait "$update_pid" || true
  exit 1
fi
echo "UPDATE_ACTIVE_AND_PAUSED time=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)"
cat "$observer_before_log"

echo "CONCURRENT_INSERT_START time=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ) id=200002 country=DE"
if PGAPPNAME=week4-currency-race-writer timeout 8s psql -X -v ON_ERROR_STOP=1 -c "SET lock_timeout = '2s'; SET statement_timeout = '5s'; INSERT INTO invoices (id, country, amount) VALUES (200002, 'DE', 20.00);" >"$writer_log" 2>&1; then
  echo "CONCURRENT_INSERT_COMMITTED time=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ) id=200002 country=DE"
else
  status=$?
  cat "$writer_log"
  echo "ASSERTION_FAILED concurrent_old_schema_insert exit=$status"
  wait "$update_pid" || true
  exit 1
fi

if ! psql_ci -f "$observer_sql" >"$observer_after_log" 2>&1 || ! grep -q 'PgSleep' "$observer_after_log"; then
  echo 'ASSERTION_FAILED update_still_paused_after_insert'
  cat "$observer_after_log" || true
  wait "$update_pid" || true
  exit 1
fi
echo "UPDATE_STILL_PAUSED_AFTER_INSERT time=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)"
cat "$observer_after_log"

if wait "$update_pid"; then
  :
else
  status=$?
  cat "$update_log"
  echo "ASSERTION_FAILED backfill_update exit=$status"
  exit 1
fi
echo "UPDATE_PROCESS_FINISHED time=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)"
cat "$seed_log" "$add_log" "$control_log" "$trigger_log" "$update_log" "$writer_log"

pre_update_currency=$(psql_ci -Atc 'SELECT currency FROM invoices WHERE id = 200001;')
concurrent_currency=$(psql_ci -Atc 'SELECT currency FROM invoices WHERE id = 200002;')
mismatches=$(psql_ci -Atc "SELECT count(*) FROM invoices WHERE currency IS DISTINCT FROM CASE country WHEN 'DE' THEN 'EUR' WHEN 'ID' THEN 'IDR' ELSE 'USD' END;")
rows=$(psql_ci -Atc 'SELECT count(*) FROM invoices;')
updated_rows=$(awk '/^UPDATE / {print $2}' "$update_log")
timing_count=$(awk '$1 == "Time:" && $3 == "ms" {count++} END {print count + 0}' "$update_log")
update_ms=$(awk '$1 == "Time:" && $3 == "ms" {print $2}' "$update_log")
assert_eq "$pre_update_currency" 'EUR' 'pre_update_insert_backfilled_positive_control'
assert_eq "$rows" '100002' 'all_rows_accounted_for'
assert_eq "$timing_count" '1' 'backfill_timing_record_count'
if [[ ! "$updated_rows" =~ ^[0-9]+$ || ! "$mismatches" =~ ^[0-9]+$ || ! "$update_ms" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "ASSERTION_FAILED unparsable_observation update_rows=<$updated_rows> mismatches=<$mismatches> update_ms=<$update_ms>"
  exit 1
fi
awk -v elapsed="$update_ms" 'BEGIN { if (elapsed + 0 < 5000) exit 1 }' || {
  echo "ASSERTION_FAILED pause_duration_ms expected_at_least=<5000> actual=<$update_ms>"
  exit 1
}
echo "ASSERTION_PASS pause_duration_ms value=<$update_ms>"
echo "OBSERVED_RESULT pre_update_currency=<$pre_update_currency> concurrent_currency=<$concurrent_currency> mismatches=<$mismatches> updated_rows=<$updated_rows> rows=<$rows>"
if [[ "$concurrent_currency" == 'USD' && "$mismatches" == '1' && "$updated_rows" == '100001' ]]; then
  echo 'EXPERIMENT_FINDING=HYPOTHESIS_SUPPORTED'
elif [[ "$concurrent_currency" == 'EUR' && "$mismatches" == '0' && "$updated_rows" == '100002' ]]; then
  echo 'EXPERIMENT_FINDING=HYPOTHESIS_REFUTED'
else
  echo 'EXPERIMENT_FINDING=INCONCLUSIVE; inspect observed values and raw logs'
fi
echo 'HARNESS_ASSERTIONS=PASS; OBSERVATIONS_RECORDED=YES'
