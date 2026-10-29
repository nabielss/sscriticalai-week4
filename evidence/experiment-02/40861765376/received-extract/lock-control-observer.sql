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
