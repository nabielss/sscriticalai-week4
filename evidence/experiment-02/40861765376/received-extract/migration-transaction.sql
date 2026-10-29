\set ON_ERROR_STOP on
\timing on
BEGIN;
\echo STEP_START add_currency
SELECT clock_timestamp();
ALTER TABLE invoices ADD COLUMN currency text NOT NULL DEFAULT 'USD';
SELECT clock_timestamp();
\echo STEP_END add_currency
\echo STEP_START update_currency
SELECT clock_timestamp();
UPDATE invoices SET currency = CASE country WHEN 'DE' THEN 'EUR' WHEN 'ID' THEN 'IDR' ELSE 'USD' END;
SELECT clock_timestamp();
\echo STEP_END update_currency
\echo STEP_START create_index
SELECT clock_timestamp();
CREATE INDEX invoices_currency_idx ON invoices (currency, created_at);
SELECT clock_timestamp();
\echo STEP_END create_index
\echo STEP_START rename_amount
SELECT clock_timestamp();
ALTER TABLE invoices RENAME COLUMN amount TO total_amount;
SELECT clock_timestamp();
\echo STEP_END rename_amount
\echo STEP_START add_check
SELECT clock_timestamp();
ALTER TABLE invoices ADD CONSTRAINT amount_nonneg CHECK (total_amount >= 0);
SELECT clock_timestamp();
\echo STEP_END add_check
COMMIT;
