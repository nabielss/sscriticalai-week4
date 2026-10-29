# Week 4 — The Migration That Passed Staging

> **Provenance:** This answer is a Nabiel–AI synthesis from dialogue and review. It uses Nabiel's pre-analysis baseline and CI runs triggered by Nabiel; Codex authored the harness and helped audit evidence. It is not represented as solo-authored work.

## 1) Verdict

**REJECT the submitted migration for this release as written.** Evidence now directly demonstrates old-schema application failures after the rename, currency loss on `down()`, and an incorrect USD currency for a DE invoice inserted after the backfill UPDATE snapshot starts. The 100k synthetic CI runs do not establish production duration, p99, 800 inserts/s impact, replica lag, or a safe deployment sequence.

## 2) Issues found (line numbers)

- **L2 — default and write correctness.** `DEFAULT 'USD'` assigns USD to old-app inserts that omit `currency`. The migration assumes every such invoice should be USD unless its country is DE or ID. The valid source of invoice currency and the full country/currency mapping are `UNKNOWN`. PostgreSQL 16 handles a constant default without rewriting every row, but that does not solve currency correctness or prove production timing; [ALTER TABLE documentation](https://www.postgresql.org/docs/16/ddl-alter.html).
- **L3–4 — full-table backfill and concurrent inserts.** One unbatched UPDATE touches all rows. In the autocommit race experiment, a DE row committed after the UPDATE snapshot began was not updated and retained USD. PostgreSQL Read Committed uses the command-start snapshot for target rows; [transaction isolation documentation](https://www.postgresql.org/docs/16/transaction-iso.html). The test proves a mechanism on a controlled fixture; production frequency and impact remain unknown. WAL, table growth, replica lag, and production backfill time were not measured.
- **L5 — ordinary index build.** `CREATE INDEX` without `CONCURRENTLY` blocks table writes while building ([PostgreSQL 16 documentation](https://www.postgresql.org/docs/16/sql-createindex.html)). Experiment 02 did not isolate index lock duration from the surrounding migration, and its 100k fixture is not a production timing estimate. If `CONCURRENTLY` is considered, the actual runner's transaction behavior and failed/invalid-index recovery must be verified first.
- **L6 — rolling-deploy incompatibility.** `amount` is renamed before new pods roll out. In Run 04, old `SELECT amount` and `INSERT (... amount ...)` succeeded before the rename and failed afterward with missing-column errors. Old pods remain for about five minutes by challenge fact. Dashboard impact is conditional on whether its queries use `amount`; that query was not supplied or tested.
- **L7 — constraint validation and rollback residue.** Adding `CHECK (total_amount >= 0)` validates existing rows and can require a scan/lock ([ALTER TABLE documentation](https://www.postgresql.org/docs/16/sql-altertable.html)). Production-scale effect is `NOT RUN`. The constraint persists after `down()`; a later negative `amount` write could fail, although whether such writes exist is `UNKNOWN`.
- **L10–13 — destructive rollback.** `down()` drops `currency`, including stored non-USD values, and renames the amount column back. The fixture's amount sum stayed 60.00, but the currency column was gone and an explicit EUR override could not be recovered. The currency index was automatically removed with the column; its disappearance is not itself a rollback defect.

## 3) Follow-up prompt

```text
Review this PostgreSQL migration as a production change under a rolling deploy.
Do not accept “it passed staging,” “zero downtime,” “safe during business hours,”
or “fully reversible” without evidence that covers the relevant workload and data.

Separate challenge facts, confirmed owner facts, rig facts, observations,
inferences, hypotheses, unknowns, and NOT RUN. Do not invent production
configuration, SLO thresholds, currency rules, or runner transaction behavior.

First identify the authoritative source for invoice currency, every old/new app
and dashboard read/write of amount/currency, PostgreSQL version, migration-runner
transaction semantics, and deployment capabilities. Stop and list owner questions
if any answer changes the safe sequence.

Then propose a staged expand/backfill/validate/contract plan that keeps old and
new app versions compatible, assigns correct currency to writes during backfill,
can resume after partial failure, and does not destroy currency on rollback.
Explain locks, index strategy, batches/checkpoints, WAL/replica monitoring,
idempotency, validation, rollback limits, and operational stop conditions.

For every claim, give a synthetic GitHub Actions test with a positive control,
an assertion that can fail, exact raw artifacts, actor/data/rig provenance, and
limitations. Include a test for an old-schema insert committed after the backfill
snapshot starts. Do not run anything on production or use production data or
credentials. End with GO/NO-GO gates and Plan B, then STOP before implementing
or triggering any workflow.
```

## 4) Evidence required

**Challenge facts:** 120M rows / approximately 180 GB including indexes, peak 800 inserts/s, six pods in a roughly five-minute rolling deploy, active reads and replica dashboards, staging 500k rows with no traffic and one pod. These are scenario facts, not CI measurements.

**Observed CI evidence:**

- Run 04 / Experiment 01: [Actions run 40861368934](https://github.com/nabielss/sscriticalai-week4/actions/runs/40861368934), commit `11761d3`, 3 synthetic rows, PostgreSQL 16.15. Raw ZIP and logs: [evidence directory](evidence/experiment-01/40861368934/). Old SELECT/INSERT fail after rename; after `down()`, currency column count is zero and the check remains.
- Experiment 02: [Actions run 40861765376](https://github.com/nabielss/sscriticalai-week4/actions/runs/40861765376), same commit, 100k synthetic rows, 25 sequential writer attempts per mode. Transaction simulation: 2 lock timeouts and 8 observed lock-wait samples. Autocommit simulation: 5 inserts and 20 old-column failures; observer sampled 0 waits, which does not prove no wait. It was not an 800/s test. [Raw ZIP and extracted files](evidence/experiment-02/40861765376/).
- Experiment 03: [Actions run 40866063966](https://github.com/nabielss/sscriticalai-week4/actions/runs/40866063966), commit `65a109c`, 100k synthetic rows, PostgreSQL 16.15, Read Committed, autocommit scope. Same UPDATE PID was observed in `PgSleep` before and after a successful concurrent insert; the queried result was `EUR` for the pre-update control and `USD` for the concurrent DE invoice, with one mismatch. `UPDATE` reported 100,001 rows and 5350.541 ms, including the deliberate five-second pause. The final query values are summarized by the script; individual final SELECT stdout files were not separately retained. [Raw ZIP and extracted logs](evidence/experiment-03/40866063966/).

For Experiment 03, rig provenance records `SCRIPT_AUTHOR=Codex`, `TRIGGERED_BY=nabielss`, `EXECUTED_ON=GitHub Actions 1000000017`, `REVIEWED_BY=Nabiel`, and `MANUAL_CHECK=POST_RUN_REVIEW_PENDING`. Nabiel later clarified that the review, prediction, and interpretation were a dialectical Nabiel–AI synthesis. The archive digest matched the Actions digest; script/workflow hashes matched the run commit. The runner snapshot was 2 CPUs, 8,122,984 kB total memory, 7,165,400 kB available, 13 GB free disk; Actions quota remains `UNKNOWN`.

**NOT RUN:** production data/configuration, actual migration-runner transaction behavior, 800 inserts/s, p99, production scale, replica lag, production dashboard SQL, complete currency mapping, repeated runs, partial failure/resume/retry, and any mitigation candidate. The 120M-row/~180 GB fixture was not run and must not be inferred to fit the standard runner.

## 5) Verification plan including Plan B

1. **Owner facts first:** confirm PostgreSQL version, runner transaction boundaries and cancellation semantics, schema/index widths, all old/new app and dashboard queries, canonical currency source/mapping, deploy-phase capabilities, and approved operational thresholds. If no safe path assigns currency to writes from still-running old pods, keep the release **NO-GO**.
2. **Candidate design, not yet tested:** preserve `amount`; add schema compatibly; deploy code that can read/write both representations; assign currency from an owner-approved source; backfill in bounded, idempotent batches with checkpoints; reconcile rows and currency totals; build needed indexes using a runner-compatible strategy; validate constraints separately; remove/rename old fields only after every old pod and dashboard consumer is gone. If the pipeline cannot sequence these phases while preserving correct writes, split the release or hold it. Do not treat the current `down()` as recovery.
3. **CI gates:** on fresh synthetic databases, test old/new app reads and writes across old/expanded schema; test DE, ID, other/unknown countries and inserts before/during/after backfill; retain known-bad and positive controls; inject failure between batches and prove retry/resume; measure phase-specific lock waits and writer outcomes. Record raw SQL output, attempt latency, row/currency reconciliation, WAL/disk, runner/image/version, commit and hashes. Only increase fixture sizes after measured footprint, free-disk reserve, timeout and Actions quota are known. Do not extrapolate linearly.
4. **If migration has not started:** block this migration/release and require owner review of a tested candidate.
5. **If it is running and the app hangs:** pause further rollout; notify the database/on-call and application owners; capture current migration statement, `pg_stat_activity`/`pg_locks`, application errors, writer outcomes, and replica health. Follow only a pre-agreed cancellation procedure after confirming transaction state. Do not blindly run `down()`, kill a backend, or rerun the migration: transaction and partial-commit behavior are unknown and `down()` destroys currency. Preserve the current schema/data, determine exactly which statements committed, restore service with a compatible app version or an owner-reviewed forward repair, then reconcile currency from its authoritative source. If that source is unavailable, keep the affected invoicing path under the business owner's incident decision rather than guessing currencies.

## 6) Confidence

**High** that the submitted migration cannot be accepted as written: old-column breakage and rollback loss were directly reproduced, and the currency race was directly observed in a controlled synthetic run. **Medium** that production writes would experience similar failure mechanisms, conditional on the actual app queries and migration runner. **Low** on production duration, p99 impact, number of incorrect invoices, replica lag, and safe cancellation because those were not tested or supplied.

## 7) What I accepted, changed or rejected from the AI

- **Accepted:** review the migration against old/new app coexistence, data correctness, write blocking, and rollback data loss; use staged expand/backfill/contract as a candidate direction; require evidence beyond staging time.
- **Changed:** the baseline expected inserts after the UPDATE completed to be at risk. Experiment 03 showed the risk begins earlier: a DE insert committed after the UPDATE snapshot starts can be missed while it is still running. Experiment 02's four suspected USD rows remain an inference; Experiment 03 directly observed one controlled row.
- **Rejected:** “tested on staging in 1.8 s” as proof of production safety, “zero downtime,” “fully reversible,” and “safe during business hours.” No production-readiness claim follows from the CI runs.
- **Attribution:** this is the Nabiel–AI synthesis. Nabiel supplied the baseline, triggered CI, reviewed artifacts in dialogue with AI, and corrected the interpretation; Codex authored the harness and assisted with evidence audit and drafting.
