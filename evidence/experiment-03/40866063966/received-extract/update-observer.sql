SELECT clock_timestamp(), pid, state, wait_event_type, wait_event, query
FROM pg_stat_activity
WHERE application_name = 'week4-currency-race-migration'
  AND state = 'active'
  AND wait_event = 'PgSleep';
