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
