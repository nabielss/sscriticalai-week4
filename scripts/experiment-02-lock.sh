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

echo 'EXPERIMENT=02 LOCK_AND_BOUNDED_WRITER_CALIBRATION'
echo 'DATA=100000 deterministic synthetic invoices; no external data'
echo 'SCOPE=transaction and per-statement-commit simulations; actual migration runner remains UNKNOWN'
echo 'WRITER=25 old-schema insert attempts, lock_timeout=250ms, sleep=100ms between attempts; not an 800 inserts/s benchmark'
echo 'SAFETY_GUARD=environment check only; not a security boundary'
psql_ci -c 'SELECT version();'

record_runner_snapshot() {
  echo "RUNNER_SNAPSHOT=$1 time=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "CPU_COUNT=$(nproc)"
  grep -E 'MemTotal|MemAvailable' /proc/meminfo
  df -h "$GITHUB_WORKSPACE"
}

seed_fixture() {
  psql_ci <<'SQL'
DROP TABLE IF EXISTS invoices;
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
  local rows
  rows=$(psql_ci -Atc 'SELECT count(*) FROM invoices;')
  assert_eq "$rows" '100000' 'calibration_seed_rows'
}

observer_sql() {
  local path="$1"
  cat >"$path" <<'SQL'
\pset format unaligned
\pset tuples_only on
\pset pager off
SELECT 'LOCK_WAIT|app=' || a.application_name || '|pid=' || a.pid ||
       '|wait_event_type=' || a.wait_event_type || '|wait_event=' || a.wait_event ||
       '|mode=' || l.mode || '|granted=' || l.granted ||
       '|blockers=' || pg_blocking_pids(a.pid)::text || '|query=' || a.query
FROM pg_stat_activity AS a
JOIN pg_locks AS l ON l.pid = a.pid
WHERE l.relation = 'public.invoices'::regclass
  AND NOT l.granted
ORDER BY a.pid;
\echo OBSERVER_READY
\watch interval=0.1 count=100
SQL
}

wait_observer_ready() {
  local pid="$1" log="$2"
  for _ in {1..100}; do
    if grep -Fq 'OBSERVER_READY' "$log"; then return 0; fi
    if ! kill -0 "$pid" 2>/dev/null; then cat "$log"; return 1; fi
    sleep 0.05
  done
  echo "ASSERTION_FAILED observer_ready log=$log"
  return 1
}

run_lock_positive_control() {
  echo 'LOCK_OBSERVER_POSITIVE_CONTROL=begin'
  seed_fixture
  local observer_log="$RUN_ARTIFACT_DIR/lock-control-observer.log"
  local holder_log="$RUN_ARTIFACT_DIR/lock-control-holder.log"
  local writer_log="$RUN_ARTIFACT_DIR/lock-control-writer.log"
  local observer_sql_file="$RUN_ARTIFACT_DIR/lock-control-observer.sql"
  observer_sql "$observer_sql_file"
  PGAPPNAME=week4-lock-observer psql_ci -f "$observer_sql_file" >"$observer_log" 2>&1 &
  local observer_pid=$!
  if ! wait_observer_ready "$observer_pid" "$observer_log"; then
    kill "$observer_pid" 2>/dev/null || true
    wait "$observer_pid" 2>/dev/null || true
    return 1
  fi
  (
    PGAPPNAME=week4-lock-control-holder psql_ci >"$holder_log" 2>&1 <<'SQL'
BEGIN;
LOCK TABLE invoices IN ACCESS EXCLUSIVE MODE;
SELECT 'CONTROL_LOCK_ACQUIRED|' || pg_backend_pid();
SELECT pg_sleep(2);
COMMIT;
SQL
  ) &
  local holder_pid=$!

  local found=0
  for _ in {1..100}; do
    if [[ "$(psql_ci -Atc "SELECT count(*) FROM pg_locks WHERE relation = 'public.invoices'::regclass AND mode = 'AccessExclusiveLock' AND granted;")" == '1' ]]; then
      found=1
      break
    fi
    sleep 0.05
  done
  if [[ "$found" != '1' ]]; then
    echo 'ASSERTION_FAILED lock_control_holder_acquired'
    kill "$holder_pid" "$observer_pid" 2>/dev/null || true
    wait "$holder_pid" 2>/dev/null || true
    wait "$observer_pid" 2>/dev/null || true
    return 1
  fi

  if PGAPPNAME=week4-lock-control-writer psql_ci -c "SET lock_timeout = '250ms'; INSERT INTO invoices (id, country, amount) VALUES (200001, 'DE', 10.00);" >"$writer_log" 2>&1; then
    echo 'ASSERTION_FAILED lock_control_writer_should_timeout'
    wait "$holder_pid" || true
    wait "$observer_pid" || true
    return 1
  fi
  cat "$writer_log"
  if ! grep -Fq 'canceling statement due to lock timeout' "$writer_log"; then
    echo 'ASSERTION_FAILED lock_control_writer_failed_for_unexpected_reason'
    wait "$holder_pid" || true
    wait "$observer_pid" || true
    return 1
  fi

  wait "$holder_pid"
  wait "$observer_pid"
  cat "$observer_log"
  if ! grep -Fq 'LOCK_WAIT|app=week4-lock-control-writer' "$observer_log"; then
    echo 'ASSERTION_FAILED lock_observer_missed_positive_control'
    return 1
  fi
  echo 'ASSERTION_PASS lock_control_writer=timeout'
  echo 'ASSERTION_PASS lock_observer=observed_ungranted_lock'
}

make_migration_sql() {
  local mode="$1" path="$2"
  {
    echo '\set ON_ERROR_STOP on'
    echo '\timing on'
    if [[ "$mode" == transaction ]]; then echo 'BEGIN;'; fi
    local label sql
    local -a labels=(add_currency update_currency create_index rename_amount add_check)
    local -a statements=(
      "ALTER TABLE invoices ADD COLUMN currency text NOT NULL DEFAULT 'USD'"
      "UPDATE invoices SET currency = CASE country WHEN 'DE' THEN 'EUR' WHEN 'ID' THEN 'IDR' ELSE 'USD' END"
      'CREATE INDEX invoices_currency_idx ON invoices (currency, created_at)'
      'ALTER TABLE invoices RENAME COLUMN amount TO total_amount'
      'ALTER TABLE invoices ADD CONSTRAINT amount_nonneg CHECK (total_amount >= 0)'
    )
    for i in "${!labels[@]}"; do
      label="${labels[$i]}"
      sql="${statements[$i]}"
      printf '\\echo STEP_START %s\nSELECT clock_timestamp();\n%s;\nSELECT clock_timestamp();\n\\echo STEP_END %s\n' "$label" "$sql" "$label"
    done
    if [[ "$mode" == transaction ]]; then echo 'COMMIT;'; fi
  } >"$path"
}

run_writer() {
  local mode="$1" log="$2" attempt output status result
  : >"$log"
  for attempt in {1..25}; do
    if output=$(PGAPPNAME="week4-writer-$mode" psql_ci -Atc "SET lock_timeout = '250ms'; INSERT INTO invoices (id, country, amount) VALUES ($((200000 + attempt)), 'DE', 10.00);" 2>&1); then
      result=INSERTED
      status=0
    else
      status=$?
      if grep -Fq 'canceling statement due to lock timeout' <<<"$output"; then
        result=LOCK_TIMEOUT
      elif grep -Fq 'column "amount" of relation "invoices" does not exist' <<<"$output"; then
        result=OLD_COLUMN_MISSING
      else
        result=UNEXPECTED_ERROR
      fi
    fi
    printf 'WRITER_RESULT mode=%s attempt=%s time=%s result=%s psql_exit=%s\n' "$mode" "$attempt" "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)" "$result" "$status" >>"$log"
    if [[ -n "$output" ]]; then printf '%s\n' "$output" >>"$log"; fi
    sleep 0.1
  done
}

run_mode() {
  local mode="$1"
  echo "MODE_BEGIN=$mode"
  seed_fixture
  local size_before lsn_before writer_log migration_log observer_log observer_sql_file migration_sql_file
  size_before=$(psql_ci -Atc "SELECT pg_database_size(current_database());")
  lsn_before=$(psql_ci -Atc 'SELECT pg_current_wal_lsn();')
  echo "DATABASE_SIZE_BEFORE_BYTES mode=$mode value=$size_before"
  echo "WAL_LSN_BEFORE mode=$mode value=$lsn_before"

  writer_log="$RUN_ARTIFACT_DIR/writer-$mode.log"
  migration_log="$RUN_ARTIFACT_DIR/migration-$mode.log"
  observer_log="$RUN_ARTIFACT_DIR/observer-$mode.log"
  observer_sql_file="$RUN_ARTIFACT_DIR/observer-$mode.sql"
  migration_sql_file="$RUN_ARTIFACT_DIR/migration-$mode.sql"
  observer_sql "$observer_sql_file"
  make_migration_sql "$mode" "$migration_sql_file"
  record_runner_snapshot "before-$mode"

  run_writer "$mode" "$writer_log" &
  local writer_pid=$!
  local writer_ready=0
  for _ in {1..100}; do
    if grep -Fq 'WRITER_RESULT mode='"$mode"' attempt=1 ' "$writer_log"; then
      writer_ready=1
      break
    fi
    sleep 0.05
  done
  if [[ "$writer_ready" != '1' ]]; then
    echo "ASSERTION_FAILED writer_started mode=$mode"
    kill "$writer_pid" 2>/dev/null || true
    wait "$writer_pid" 2>/dev/null || true
    return 1
  fi

  PGAPPNAME="week4-observer-$mode" psql_ci -f "$observer_sql_file" >"$observer_log" 2>&1 &
  local observer_pid=$!
  if ! wait_observer_ready "$observer_pid" "$observer_log"; then
    kill "$observer_pid" "$writer_pid" 2>/dev/null || true
    wait "$observer_pid" 2>/dev/null || true
    wait "$writer_pid" 2>/dev/null || true
    return 1
  fi
  local migration_started
  migration_started=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)
  echo "MIGRATION_START mode=$mode time=$migration_started"
  local migration_status=0
  (
    export PGAPPNAME="week4-migration-$mode"
    timeout 180s psql -X -v ON_ERROR_STOP=1 -f "$migration_sql_file"
  ) >"$migration_log" 2>&1 &
  local migration_pid=$!
  if wait "$migration_pid"; then migration_status=0; else migration_status=$?; fi
  echo "MIGRATION_EXIT mode=$mode status=$migration_status time=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)"
  wait "$writer_pid"
  wait "$observer_pid"
  cat "$migration_log"
  cat "$writer_log"
  cat "$observer_log"

  local attempts unexpected lock_timeouts old_column_errors inserted db_size_after lsn_delta row_count expected_rows
  attempts=$(grep -c '^WRITER_RESULT ' "$writer_log" || true)
  assert_eq "$attempts" '25' "writer_attempts_$mode"
  unexpected=$(grep -c 'result=UNEXPECTED_ERROR' "$writer_log" || true)
  assert_eq "$unexpected" '0' "writer_unexpected_errors_$mode"
  lock_timeouts=$(grep -c 'result=LOCK_TIMEOUT' "$writer_log" || true)
  old_column_errors=$(grep -c 'result=OLD_COLUMN_MISSING' "$writer_log" || true)
  inserted=$(grep -c 'result=INSERTED' "$writer_log" || true)
  echo "WRITER_SUMMARY mode=$mode attempted=$attempts inserted=$inserted lock_timeout=$lock_timeouts old_column_missing=$old_column_errors"
  echo "OBSERVER_LOCK_SAMPLE_COUNT mode=$mode value=$(grep -c 'LOCK_WAIT|' "$observer_log" || true)"
  if [[ "$migration_status" != '0' ]]; then
    echo "MIGRATION_RESULT=FAILED mode=$mode exit=$migration_status; post-state checks NOT RUN"
    return 1
  fi

  row_count=$(psql_ci -Atc 'SELECT count(*) FROM invoices;')
  expected_rows=$((100000 + inserted))
  assert_eq "$row_count" "$expected_rows" "all_rows_accounted_for_$mode"
  db_size_after=$(psql_ci -Atc 'SELECT pg_database_size(current_database());')
  lsn_delta=$(psql_ci -Atc "SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), '$lsn_before')::bigint;")
  echo "ROW_COUNT_AFTER mode=$mode value=$row_count"
  echo "DATABASE_SIZE_AFTER_BYTES mode=$mode value=$db_size_after"
  echo "WAL_LSN_DELTA_BYTES mode=$mode value=$lsn_delta (includes concurrent writer activity)"
  record_runner_snapshot "after-$mode"
  echo "MODE_END=$mode"
}

run_lock_positive_control
run_mode transaction
run_mode autocommit
echo 'ASSERTION_BATCH_COMPLETE experiment=02 seed_rows=100000 scale_up=NOT_RUN'
