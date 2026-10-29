#!/usr/bin/env bash
set -euo pipefail

mkdir -p artifacts
exec > >(tee artifacts/experiment-01.log) 2>&1
trap 'status=$?; echo "SCRIPT_EXIT_STATUS=$status"' EXIT

psql_ci() { psql -X -v ON_ERROR_STOP=1 "$@"; }
assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" != "$expected" ]]; then
    printf 'ASSERTION_FAILED %s expected=<%s> actual=<%s>\n' "$label" "$expected" "$actual"
    exit 1
  fi
  printf 'ASSERTION_PASS %s value=<%s>\n' "$label" "$actual"
}

echo 'EXPERIMENT=01 OLD_APP_COMPATIBILITY_AND_DOWN_CURRENCY'
echo 'DATA=synthetic; no production or staging connection'
echo 'MIGRATION=verbatim SQL from ChallengeWeek4.md, wrapped in one transaction (runner behavior unknown)'
scenario=${EXPERIMENT_SCENARIO:-both}
case "$scenario" in
  compatibility|rollback|both) ;;
  *) echo "INVALID_SCENARIO=$scenario"; exit 2 ;;
esac
echo "SELECTED_SCENARIO=$scenario"
psql_ci -c 'SELECT version();'

reset_fixture() {
  psql_ci <<'SQL'
DROP TABLE IF EXISTS invoices;
CREATE TABLE invoices (
  id integer PRIMARY KEY,
  country text,
  amount numeric(12,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO invoices (id, country, amount) VALUES
  (1, 'DE', 10.00), (2, 'ID', 20.00), (3, 'US', 30.00);
SQL
}

run_up() {
  psql_ci <<'SQL'
BEGIN;
ALTER TABLE invoices ADD COLUMN currency text NOT NULL DEFAULT 'USD';
UPDATE invoices SET currency =
  CASE country WHEN 'DE' THEN 'EUR' WHEN 'ID' THEN 'IDR' ELSE 'USD' END;
CREATE INDEX invoices_currency_idx ON invoices (currency, created_at);
ALTER TABLE invoices RENAME COLUMN amount TO total_amount;
ALTER TABLE invoices ADD CONSTRAINT amount_nonneg CHECK (total_amount >= 0);
COMMIT;
SQL
}

run_compatibility() {
  echo 'SCENARIO_A=old_application_query'
  reset_fixture
  amount=$(psql_ci -Atc 'SELECT amount FROM invoices WHERE id = 1;')
  assert_eq "$amount" '10.00' 'old_query_before_rename'
  run_up
  new_value=$(psql_ci -Atc "SELECT total_amount::text || ':' || currency FROM invoices WHERE id = 1;")
  assert_eq "$new_value" '10.00:EUR' 'new_query_after_up'

  if psql_ci -c 'SELECT amount FROM invoices WHERE id = 1;' >artifacts/old-query-after-rename.log 2>&1; then
    cat artifacts/old-query-after-rename.log
    echo 'ASSERTION_FAILED old_query_after_rename unexpectedly succeeded'
    exit 1
  fi
  cat artifacts/old-query-after-rename.log
  if ! grep -Fq 'column "amount" does not exist' artifacts/old-query-after-rename.log; then
    echo 'ASSERTION_FAILED old_query_after_rename failed for an unexpected reason'
    exit 1
  fi
  echo 'EXPECTED_FINDING old_query_after_rename=FAIL column amount does not exist'
  echo 'RELEASE_GATE rolling_compatibility=FAIL (harness reproduced the defect)'
}

run_rollback() {
  echo 'SCENARIO_B=down_currency_information'
  reset_fixture
  run_up
  currencies=$(psql_ci -Atc "SELECT string_agg(id::text || ':' || currency, ',' ORDER BY id) FROM invoices;")
  assert_eq "$currencies" '1:EUR,2:IDR,3:USD' 'currency_before_down_positive_control'

  # Model an explicit invoice-currency choice that country alone cannot recover.
  psql_ci -c "UPDATE invoices SET currency = 'EUR' WHERE id = 3;"
  override=$(psql_ci -Atc 'SELECT currency FROM invoices WHERE id = 3;')
  assert_eq "$override" 'EUR' 'explicit_currency_before_down'
  amount_sum_before=$(psql_ci -Atc 'SELECT sum(total_amount) FROM invoices;')
  echo "SNAPSHOT_BEFORE_DOWN currencies=$currencies; id3_currency_override=$override; amount_sum=$amount_sum_before"

  psql_ci <<'SQL'
BEGIN;
ALTER TABLE invoices DROP COLUMN currency;
ALTER TABLE invoices RENAME COLUMN total_amount TO amount;
COMMIT;
SQL

  currency_columns=$(psql_ci -Atc "SELECT count(*) FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'invoices' AND column_name = 'currency';")
  amount_columns=$(psql_ci -Atc "SELECT count(*) FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'invoices' AND column_name = 'amount';")
  assert_eq "$currency_columns" '0' 'currency_column_after_down'
  assert_eq "$amount_columns" '1' 'amount_column_after_down'
  amount_sum_after=$(psql_ci -Atc 'SELECT sum(amount) FROM invoices;')
  assert_eq "$amount_sum_after" "$amount_sum_before" 'amount_sum_after_down'
  check_constraints=$(psql_ci -Atc "SELECT count(*) FROM pg_constraint WHERE conrelid = 'invoices'::regclass AND conname = 'amount_nonneg';")
  assert_eq "$check_constraints" '1' 'amount_nonneg_constraint_persists_after_down'
  echo 'EXPECTED_FINDING currency_after_down=ABSENT; explicit currency value is not preserved by down()'
  echo 'EXPECTED_FINDING amount_nonneg_constraint_after_down=PRESENT; schema is not identical to pre-up state'
  echo 'RELEASE_GATE down_preserves_currency=FAIL (harness reproduced the defect)'
}

if [[ "$scenario" == compatibility || "$scenario" == both ]]; then run_compatibility; fi
if [[ "$scenario" == rollback || "$scenario" == both ]]; then run_rollback; fi
echo 'EXPERIMENT_HARNESS=PASS; MIGRATION_DECISION=REJECT'
