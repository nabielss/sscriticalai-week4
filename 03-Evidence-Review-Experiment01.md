# Review Evidence — Experiment 01

Status: three CI runs reviewed; no database work run locally. This review is AI-authored from the challenge, committed harness, three CI artifacts, and Nabiel's separately preserved interpretations and source reviews.

## Run card

| Field | Value |
|---|---|
| Run | [GitHub Actions run 40848098217](https://github.com/nabielss/sscriticalai-week4/actions/runs/40848098217), attempt 1 |
| Commit | `99b21a45397083b19c6dafc61d5bbfb62e305057` |
| SCRIPT_AUTHOR | Codex (AI assistant) |
| TRIGGERED_BY | `nabielss` (reported by Actions) |
| EXECUTED_ON | GitHub-hosted Actions, Linux/X64; runner name `GitHub Actions 1000000011` |
| REVIEWED_BY | Run 01 log records `Nabiel`. A later user-provided transcript contains a source-level review of the script/workflow; this supports Nabiel's self-review, though its exact timestamp and local-file hash were not recorded. Triggerer and reviewer are the same person; no independent second reviewer. |
| MANUAL_CHECK | Raw run logs still say `POST_RUN_REVIEW_PENDING`; Nabiel later reported reading the logs and supplied interpretations for both runs, plus a source review in [the Run 02 transcript](evidence/experiment-01/40849504741/Nabiel-pasted-review-and-run-transcript.txt). These are user-reported checks preserved as follow-up evidence; original logs remain unchanged. |
| Data | Three fixed synthetic invoices; ids 1–3; no staging/production data |
| Database | PostgreSQL 16.15 (Debian); image label `postgres:16`, patch not pinned |
| Runner facts observed | 2 CPUs; `MemTotal=8,122,984 kB`, `MemAvailable=7,121,200 kB`; `/dev/root` 72 GB total, 13 GB available at measurement |
| Command | `bash scripts/experiment-01.sh`; selected scenario `both` |
| Raw output | `artifacts/week4-experiment-01-40848098217-1/` (3 files) |
| Limits | One tiny fixture, one run, no concurrent sessions, no time/lock/throughput/WAL/disk-per-database/replica measurements; migration transaction wrapper is imposed by the harness, not confirmed for the real runner. |

The attached `old-query-after-rename.log` duplicates the corresponding Postgres error in `experiment-01.log`; it is a convenience capture, not independent evidence. The harness's `EXPERIMENT_HARNESS=PASS` means its expected defect assertions passed; it does not mean the migration passed a release gate. The explicit release-gate markers say both properties fail.

## Run 02 — rollback/index, 2026-10-29

| Field | Value |
|---|---|
| Run | [GitHub Actions run 40849504741](https://github.com/nabielss/sscriticalai-week4/actions/runs/40849504741), attempt 1 |
| Commit | `a579dc13f3e6d8f354195a2bb8bbe56f463f0396` |
| Scenario | `rollback` only; compatibility case did not run |
| SCRIPT_AUTHOR / TRIGGERED_BY / EXECUTED_ON | Codex / `nabielss` / GitHub-hosted Linux X64 (`GitHub Actions 1000000012`) |
| Reviewer / manual check | Workflow input says `Nabiel`; source review is supplied in [Nabiel's pasted transcript](evidence/experiment-01/40849504741/Nabiel-pasted-review-and-run-transcript.txt). The raw artifact still says `POST_RUN_REVIEW_PENDING`; the user later supplied a post-run interpretation. Code/workflow hashes were not recorded, so exact local-review-to-commit identity is not independently verifiable. |
| Database/data | PostgreSQL 16.15; three fixed synthetic invoices; migration wrapped in one transaction |
| Runner facts | 2 CPUs; `MemTotal=8,122,984 kB`, `MemAvailable=7,133,528 kB`; `/dev/root` 13 GB free at measurement |
| Raw evidence | `evidence/experiment-01/40849504741/received-extract/` and `original-artifact.zip`; user-provided run/review transcript is alongside them |

**OBSERVED:** `CREATE INDEX` returned successfully before `down()`, and `pg_indexes` returned count 0 afterward. The assertion passed, but there was no count/index-definition query before `down()`. The pre-down `CREATE INDEX` command is a positive signal, not the positive-control count requested in the review. The updated harness now asserts count 1 and prints `indexdef` before down, then prints/checks the catalog after; that revision is `NOT RUN`.

**OBSERVED:** the same rollback run reports currency column count 0, amount sum 60.00, and check-constraint count 1. It did not run the compatibility scenario, which remains supported by Run 01 only.

**OBSERVED artifact contamination:** the uploaded Run 02 archive contains six files: two Run 02 root logs plus four files from Run 01 (the older three-log extract and its zip). The cause is established by repository history: Run 01 evidence had been committed under the workflow's `artifacts/` output directory, and the workflow used `mkdir -p` without clearing that path. The original contaminated zip and extracted contents are preserved under `evidence/`; `/artifacts/` is now ignored so workflow output stays separate from retained evidence.

Nabiel's post-run interpretation and source-level review are preserved in the transcript. It correctly points out the missing pre-down index count, literal verdict text, absent file hashes, locally unsafe `DROP TABLE` target, and output-log race. These findings are addressed in the current, unrun script/workflow revision. `REVIEWED_BY=Nabiel` means a human self-review was reported; it is not an independent second-person review.

## Run 03 — both correctness scenarios and provenance, 2026-10-29

| Field | Value |
|---|---|
| Run | [GitHub Actions run 40851077057](https://github.com/nabielss/sscriticalai-week4/actions/runs/40851077057), attempt 1 |
| Commit | `c0e75af5e842348f98aac833c2de25e430d559bb` |
| Scenario / actor | `both`; triggered by `nabielss` |
| SCRIPT_AUTHOR / EXECUTED_ON | Codex (AI assistant) / GitHub-hosted Linux X64 (`GitHub Actions 1000000014`) |
| Reviewer / manual check | Raw log says `REVIEWED_BY=Nabiel` and `MANUAL_CHECK=POST_RUN_REVIEW_PENDING`. Nabiel's supplied review, full Actions transcript, and post-run interpretation are preserved in [the Run 03 transcript](evidence/experiment-01/40851077057/Nabiel-run-review-transcript.txt). This documents a self-review and user-run review of raw results, not an independent second reviewer. |
| Script/workflow identity | Rig-log SHA-256 values match the repository files at commit `c0e75af`: script `b1442f97202172949b18efaa7581e0c2e9ad55e9791c82082466698832bfccce`; workflow `846a5cd8f1fe879a745b22a92d212457414dcb99441eaed43aaece02f554b5e5`. |
| Data / database | Three deterministic synthetic invoices; PostgreSQL 16.15; service image `postgres:16`, pulled digest `sha256:1beaa3084eee2676f20a9cd9928f0bf2c5bf674f8e49f81017912183d377c61c` |
| Runner facts | 2 CPUs; `MemTotal=8,122,984 kB`, `MemAvailable=7,137,744 kB`; `/dev/root` 72 GB total, 13 GB free at measurement. These are startup snapshots, not DB capacity guarantees. |
| Raw artifacts | `evidence/experiment-01/40851077057/received-extract/` (three files) plus preserved original ZIP and user-supplied transcript. The uploaded ZIP SHA-256 matches the digest printed by the Actions upload step: `0dd1a05850cc03cb9d6a98d5076d9f145e81b6e64a1c99988009fcb8055d45e0`. |
| Exit | `SCRIPT_EXIT_STATUS=0`; all scripted assertions completed. This is harness success, not migration approval. |

**OBSERVED:** both prior correctness findings reproduced. The old `SELECT amount` succeeds before `up()` and fails after the rename. Postgres service logs in the supplied full Actions transcript independently show the server-side missing-column error and exact statement; this corroborates the client capture but is still the same run/environment.

**OBSERVED with positive control:** `pg_indexes` returns one `invoices_currency_idx` row before `down()` and prints its raw definition (`CREATE INDEX ... USING btree (currency, created_at)`); after `down()`, the catalog query returns `(0 rows)` and the assertion count is 0. This closes the pre/post index evidence gap from Run 02.

**OBSERVED:** after `down()`, `currency_column_after_down=0`, `amount_column_after_down=1`, `amount_sum_after_down=60.00`, and `amount_nonneg_constraint_persists_after_down=1`. An explicit synthetic EUR override on the US fixture row was present before `down()`. The sum assertion does not verify every amount row.

**Provenance cross-check:** I compared the SHA-256 values in the rig artifact with the checked-out files at the logged commit and computed the downloaded ZIP SHA-256; all match Nabiel's supplied report. The extracted ZIP contains three files and no older-run files. The uploaded archive digest match establishes byte identity with the supplied download, not independent GitHub attestation. The repo tree at `c0e75af` has no tracked `artifacts/` entries; the clean Run 03 artifact is consistent with that fact. The workflow's `mkdir -p artifacts` does not clear existing files if a workspace is reused.

**Contribution boundary:** Actions records `TRIGGERED_BY=nabielss`; I record this as a user-triggered CI run. `SCRIPT_AUTHOR` remains AI. The pasted review and result interpretation are Nabiel-authored user contributions; the raw artifact's pending marker remains unchanged.

**Still NOT RUN:** old-app `INSERT (amount)` after rename; concurrent traffic/lock measurement; scale/backfill/WAL/replica impact; partial failure/resume; and production migration-runner behavior. The old-app INSERT assertion has now been added to the harness but awaits a user-triggered Run 04. The harness wraps both `up()` and `down()` in transactions, while the real runner behavior is unknown. Run 03 establishes correctness defects on a three-row PostgreSQL 16.15 fixture, not production timing or lock impact.

## Observations and inference

### Compatibility

- **OBSERVED:** before `up()`, `SELECT amount ... id=1` returns `10.00`.
- **OBSERVED:** after the committed `up()`, `total_amount/currency` returns `10.00:EUR`.
- **OBSERVED:** the same old-column query fails with Postgres `ERROR: column "amount" does not exist`.
- **DERIVED, conditional:** any still-serving old pod whose SQL references `amount` will fail after the rename becomes visible. The brief establishes five minutes of old/new coexistence, but does not include the actual old app SQL; the synthetic query matches the old schema contract in the challenge.

### `down()`

- **OBSERVED:** backfill gives `1:EUR,2:IDR,3:USD`; after a synthetic explicit currency change, id 3 reads EUR before rollback.
- **OBSERVED:** after `down()`, `currency` column count is 0, `amount` column count is 1, the amount sum remains `60.00`, and constraint `amount_nonneg` remains.
- **DERIVED:** `down()` does not preserve currency values independently of country. The explicit id 3 EUR override on country US is the harness's synthetic falsifier for the assumption that country always determines currency; it is not a challenge fact about valid business inputs.
- **LIMIT:** the harness checks the sum, not every amount row. The SQL in `down()` only drops/renames columns, so it has no statement that changes amount values, but the empirical assertion is still sum-only.

### Index cleanup correction

Run 03 directly observed `invoices_currency_idx` count 1 plus its index definition after `up()`, then count 0 after `down()`. PostgreSQL docs say `ALTER TABLE ... DROP COLUMN` automatically drops indexes and table constraints involving that column. The absence of an explicit `DROP INDEX` is not itself a defect. Source: [PostgreSQL 16 ALTER TABLE](https://www.postgresql.org/docs/16/sql-altertable.html).

The leftover `amount_nonneg` is different: it references the renamed amount column, not `currency`, so dropping `currency` does not drop that check. Its persistence is directly observed in this run.

## Lock reasoning — what the run did not test

The committed script wraps all `up()` statements in `BEGIN`/`COMMIT`. The real migration runner's transaction behavior is `UNKNOWN`. This choice makes the tiny test deterministic, but it prevents the run from identifying where lock waits occur.

- PostgreSQL `ALTER TABLE` generally takes `ACCESS EXCLUSIVE` unless a subform documents a weaker lock. In a single transaction, the lock from the first `ALTER TABLE ADD COLUMN` is held until commit; with this script that spans the update, index build, rename, and check validation. That can block readers and writers. This is a documented mechanism, not measured impact at production scale.
- If statements commit separately, locks from each DDL statement end at that statement's commit; ordinary `CREATE INDEX` blocks writes while its build runs. The `CHECK` scan also locks out other table changes until commit. The exact live wait times depend on size, hardware, workload, and transaction history.
- The large `UPDATE` is not by itself evidence that all inserts are blocked by an exclusive table lock. It does generate substantial tuple writes/WAL and can leave dead tuples and replica replay work. Its impact needs measurement.
- **Do not describe time as linear in row count without scale points/raw measurements.** The user's p99 prediction needs per-statement timing, lock wait duration/count, writer success/error/latency, plus the actual migration transaction mode.

Sources: [PostgreSQL 16 ALTER TABLE](https://www.postgresql.org/docs/16/sql-altertable.html), [CREATE INDEX](https://www.postgresql.org/docs/16/sql-createindex.html).

## Runner capacity and scale gate

Both CI rig logs observe 2 CPUs, about 7.75 GiB reported total memory, and 13 GB free on `/dev/root` at startup. That is a runner snapshot, not a database memory/disk quota and not a sustained-load guarantee. The hosted runner was not measuring a PostgreSQL instance seeded with the production schema.

**DERIVED planning bound:** challenge data is approximately `180 GB / 120M = 1.5 kB` per invoice including indexes. At that average, 5M rows imply roughly 7.5 GB and 20M roughly 30 GB before WAL, temporary files, filesystem overhead, and image/service files. Therefore 20M is not a valid target on this runner; 5M is also too close to the observed free disk to promise. This projection is not a measured fixture size. Begin with a small calibration seed, record physical DB and WAL footprint, and only advance if space headroom is explicitly adequate. A narrower synthetic schema will be cheaper but less representative; report that limitation.

Monthly Actions allowance/spend policy remains `UNKNOWN`; this workflow's first run does not reveal account quota. Keep jobs bounded and artifacts small until account usage/settings are checked.

## Candidate repair direction — design only

**HYPOTHESIS:** use an expand/contract sequence; do not run the submitted rename before app rollout.

1. Keep `amount` during this release and introduce `currency` additively. Do not use a blanket USD default unless Finance confirms that every legacy insert omitting currency is USD.
2. Obtain the authoritative invoice-currency rule first. If currency comes from a customer/product/pricing decision rather than country, it must be written by a compatible app path; a `country → currency` trigger is not a safe substitute. During old/new pod overlap, either old writers must be made currency-aware/dual-write through a compatibility release or a validated DB-side mechanism must fill currency. If neither is possible, the no-visible-downtime constraint and correct EUR/IDR billing cannot both be claimed safe.
3. Backfill existing rows in bounded, idempotent batches with a persisted checkpoint and retry plan. Ensure concurrent inserts/updates are covered by the same authoritative write rule; compare row counts and currency totals before validation.
4. Create an index only if the actual query pattern needs it; if needed on a live PostgreSQL table, build it in a separate `CREATE INDEX CONCURRENTLY` operation outside a transaction, with invalid-index cleanup/retry documented.
5. Add/validate constraints after the data is correct. Keep the old column and compatible reads until every old app/dashboard consumer has moved. Make destructive rename/drop a later contract step after an explicit all-consumer gate, or omit the rename if there is no user-facing need.
6. Prefer application rollback to a compatible version while preserving the additive data. Treat `down()` as schema cleanup only if it is proven not to erase required currency. Do not use this `down()` as an incident recovery action.

**UNKNOWN blocking inputs:** source of truth for currency, all supported currencies/countries, old app insert/read SQL, dashboard SQL, actual migration transaction behavior, and whether column rename is a business requirement. No candidate is safe to implement until these are resolved by fixture evidence or an authorized owner answer.

## Next experiment proposal — lock and compatibility under writes

**Goal:** distinguish transaction-scoped DDL lock retention from the blocking window of individual operations; do not test a fix yet.

1. Run 03 closes the positive-control/provenance gate for the current revision: hashes match the committed script/workflow, and Nabiel supplied a source review and post-run interpretation. His transcript flags the missing old-app INSERT case; add that bounded correctness assertion before the next dispatch, then record the revised identity and review. A reviewer input alone does not substitute for the review record.
2. Use isolated GitHub-hosted Actions Postgres with synthetic rows and the production-like column widths/indexes only where their parameters are known. Record seed, row size, DB size, WAL size, and full migration mode. Run on fresh fixtures for each mode/size.
3. Test two modes because real runner semantics are unknown: **(A)** one transaction matching current harness; **(B)** each statement committed separately. Replace this with the actual runner behavior if its implementation/config becomes available. Never claim CI mode equals production runner without that evidence.
4. Start a bounded writer that records attempt time, completion/error, and latency. Run `up()` concurrently. A separate observer polls `pg_stat_activity` and `pg_locks` for wait event, query, granted state, and wait duration. Put a short `lock_timeout` on the writer; preserve both successful and timed-out inserts. Verify row counts/currency after the run.
5. Start with a calibration fixture (e.g. 100k), measure actual database+WAL disk footprint, then choose the next size using measured free disk with a predeclared reserve/stop limit. Do not queue 20M on the observed runner; 5M also requires a measured size and headroom gate. A size ladder may stop early and record `NOT RUN` for larger sizes.
6. Record per-step start/end and transaction boundaries so any lock wait is tied to `ADD COLUMN`, `UPDATE`, `CREATE INDEX`, rename, or `CHECK`. Collect runner CPU/memory/disk before/during/after, DB/WAL footprint, rows/sec, inserts attempted/committed/failed, lock waits, and completion times. Use multiple repetitions only after the first measured fixture fits.

**Acceptance / stop:** positive control writer inserts before migration; at least one concurrent writer and observer are active during the operation; all intended probe attempts accounted for (no unexplained missing rows); metrics identify which statement blocks which operation; raw logs/artifact upload even on failure. Stop scale-up before free disk falls below the predeclared reserve or Actions timeout. Results describe the CI rig only; they do not prove production safety or zero downtime.

No candidate fix has been implemented or tested. Preserve the `down()` findings; do not run rollback as a production recovery recommendation.

## Experiment 02 implementation — plan recorded before its run

- At the time this plan was written, Run 04 extended `compatibility` with an old-schema INSERT positive control before migration and an expected missing-column error after rename. It is in `scripts/experiment-01.sh`; the later user-triggered Run 04 is recorded below.
- New `week4-experiment-02.yml` and `scripts/experiment-02-lock.sh` set up one 100,000-row deterministic synthetic fixture. The job tests the original SQL in (A) one transaction and (B) per-statement commits, clearly labeled simulations because the real runner is unavailable.
- A deliberately held `ACCESS EXCLUSIVE` lock is the observer/writer positive control. Each migration mode then runs with one bounded legacy writer (25 attempts, 250 ms `lock_timeout`, 100 ms sleep between attempts) and a `pg_stat_activity`/`pg_locks` sampler. These settings bound the probe; they are not business SLOs and do not represent 800 inserts/second.
- The run records per-statement timings, writer outcomes, database size, WAL LSN delta, CPU/memory/disk snapshots, runner/image/database versions, hashes, and raw logs. Artifacts use a run-specific directory and `if: always()` upload. Scale-up, replica lag, and recovery are deliberately excluded from this calibration run.
- Acceptance was limited to instrumentation positive control, complete accounting of writer attempts, and successful/failed migration state with raw evidence. An unobserved lock at 100k is not evidence of no lock at production scale. The later user-triggered run 40861765376 is recorded below.

PostgreSQL 16 documentation supports the lock and measurement approach: lock-wait sessions can be joined through `pg_locks` and `pg_stat_activity`; `pg_wal_lsn_diff` reports LSN byte difference. A constant column default avoids a full-table rewrite on PostgreSQL 11+, while ordinary `CREATE INDEX` blocks writes during the build; `CREATE INDEX CONCURRENTLY` has separate transaction restrictions. Sources: [monitoring stats](https://www.postgresql.org/docs/16/monitoring-stats.html), [pg_locks](https://www.postgresql.org/docs/16/view-pg-locks.html), [WAL functions](https://www.postgresql.org/docs/16/functions-admin.html), [adding a column](https://www.postgresql.org/docs/16/ddl-alter.html), [CREATE INDEX](https://www.postgresql.org/docs/16/sql-createindex.html).

## Run 04 and Experiment 02 — user-triggered CI evidence, 2026-10-29

The original uploaded ZIPs and extracted raw files are retained under `evidence/experiment-01/40861368934/` and `evidence/experiment-02/40861765376/`. The ZIP SHA-256 values match the digests reported by the corresponding Actions uploads. Nabiel's interpretation is preserved verbatim in [his submitted interpretation](evidence/Nabiel-Interpretation-Run04-Experiment02.txt); this audit below is AI-authored and separate from that submission.

### Run cards and observed facts

| Field | Run 04 / Experiment 01 | Experiment 02 |
|---|---|---|
| Run | [40861368934](https://github.com/nabielss/sscriticalai-week4/actions/runs/40861368934) | [40861765376](https://github.com/nabielss/sscriticalai-week4/actions/runs/40861765376) |
| Commit | `11761d3b04b54d7b8fd19105547da2154c130dd8` | `11761d3b04b54d7b8fd19105547da2154c130dd8` |
| SCRIPT_AUTHOR / TRIGGERED_BY / EXECUTED_ON | Codex / `nabielss` / GitHub-hosted Linux X64 (`1000000015`) | Codex / `nabielss` / GitHub-hosted Linux X64 (`1000000016`) |
| REVIEWED_BY / MANUAL_CHECK | `Nabiel` / `POST_RUN_REVIEW_PENDING` in rig log; user later supplied an interpretation | `Nabiel` / `POST_RUN_REVIEW_PENDING` in rig log; user later supplied an interpretation |
| Data / DB | 3 deterministic synthetic invoices; PostgreSQL 16.15 | 100,000 deterministic synthetic invoices per fresh mode fixture; PostgreSQL 16.15 |
| Runner snapshot | 2 CPUs; MemTotal 8,122,984 kB; MemAvailable 7,153,972 kB; disk 72 GB total, 13 GB free | 2 CPUs; MemTotal 8,122,984 kB; MemAvailable 7,155,764 kB; disk 72 GB total, 13 GB free |
| Script / workflow SHA-256 | `bb62f5dbe6a9ec45ff78b65782bf8bd283cbff0f51e7210bd474a5f9a87a106a` / `846a5cd8f1fe879a745b22a92d212457414dcb99441eaed43aaece02f554b5e5` | `70d2578f4c45db98018a06bfe69c2ddcfb27d30312b6794e364e5f13b9b3e466` / `6b58d2dbd087bcc60869ea27c2396fe8da61c7a5465901386d2cf6854518cee1` |
| Execution bounds | `both`; migration and rollback fixture | 25 sequential writer attempts per mode, `lock_timeout=250ms`, 100 ms sleep; transaction and per-statement-commit simulations; not 800 inserts/s |
| Actions account quota | Not recorded | `UNKNOWN` in rig log |

**OBSERVED — compatibility and rollback:** Run 04 records old `SELECT amount` and old-schema `INSERT (amount)` succeeding before rename and failing after it with missing-column errors. After `down()`, currency column count is 0, amount sum is still 60.00, `amount_nonneg` remains, and the currency index count falls from 1 to 0. The index cleanup is therefore observed to happen through column removal; lack of an explicit `DROP INDEX` is not a defect here.

**OBSERVED — lock positive control:** the calibration holder caused a writer timeout, and the observer sampled an ungranted `RowExclusiveLock` wait with the holder PID as blocker. The instrumentation can detect this deliberately held lock.

**OBSERVED — transaction simulation:** migration took about 1.067 s wall-clock. Writer summary: 25 attempts, 1 inserted before migration, 2 lock timeouts, 22 old-column-missing errors, 0 unexpected errors. The observer recorded 8 samples of lock waits with the migration PID as blocker. `UPDATE` reports 100,001 rows. Database size rose from 15,244,311 to 29,424,663 bytes; WAL LSN delta was 29,310,352 bytes, explicitly including concurrent writer activity.

**OBSERVED — autocommit simulation:** migration took about 1.050 s wall-clock. Writer summary: 25 attempts, 5 inserted, 0 lock timeouts, 20 old-column-missing errors, 0 unexpected errors. The observer sampled zero lock waits. `UPDATE` reports 100,001 rows while final row count is 100,005. Database size rose from 15,260,695 to 26,729,495 bytes; WAL LSN delta was 27,689,640 bytes, including writer activity.

**DERIVED, strong but not directly value-verified:** the `UPDATE` ran from `10:59:32.522635Z` through `10:59:33.333084Z`. Writer attempts 2–4 are timestamped inside that interval and insert successfully; attempt 5 is timestamped after the update but before migration completion and also inserts. `UPDATE 100001` equals 100,000 seeded rows plus the pre-migration writer row, whereas the final count is 100,005. Combined with the `ADD COLUMN ... DEFAULT 'USD'` and `UPDATE` statement snapshot semantics at PostgreSQL's default Read Committed isolation, this strongly predicts that IDs 200002–200005 retained USD despite country DE. The run did not query their currency, and its database container is gone, so the values remain **NOT VERIFIED**. No data correctness verdict should present USD as directly observed.

### Audit of Nabiel's interpretation

- Correctly limits claims to this 100k fixture, PostgreSQL 16.15, one sequential writer, and one run per mode. Correctly refuses to infer production p99, 800/s behavior, linear scaling, replica lag, or runner transaction semantics.
- Correctly identifies that an insert may succeed while the autocommit backfill runs yet not be counted by that statement, and labels the resulting USD mismatch as unverified. The three timestamps inside the `UPDATE` window plus `UPDATE 100001` provide strong support for the hypothesis, but the currency value query is still missing.
- One wording correction: `OBSERVER_LOCK_SAMPLE_COUNT=0` means **no waits were sampled**, not that no lock wait occurred. The 100 ms polling interval can miss short waits. PostgreSQL's ordinary `CREATE INDEX` acquires `SHARE`, which conflicts with writers; this documented fact does not prove that an insert in this specific run waited. Per-attempt completion duration and finer phase-correlated lock observations are absent. PostgreSQL 16 docs: [table-level locks](https://www.postgresql.org/docs/16/explicit-locking.html), [CREATE INDEX](https://www.postgresql.org/docs/16/sql-createindex.html).
- The migration-wide writer waits in transaction mode are observed and the long-lived DDL lock is the expected documented mechanism. However, the artifact records waiter lock mode and blocker PID, not the blocker lock mode or the exact statement at each wait. Because `ADD COLUMN` begins the transaction, with DDL locks retained until transaction end, it is a strong causal explanation; the run did not isolate the incremental blocking effect of the later index/check statements. PostgreSQL 16 docs: [explicit locking](https://www.postgresql.org/docs/16/explicit-locking.html), [ALTER TABLE](https://www.postgresql.org/docs/16/sql-altertable.html).
- The proposed `pg_sleep` after `UPDATE` would insert after that backfill statement had finished. It would demonstrate that a post-backfill insert can retain the default, but it would **not** reproduce an insert during the active `UPDATE`. For a deterministic in-update reproduction, add a synthetic-only pause while the `UPDATE` is still executing, coordinate the second session after the observer sees the active statement, then query currency before discarding the fixture. An alternate post-update test can remain as a separate race window.
- The database size deltas are not direct bloat measurements. Both include concurrent inserts and the migration's physical effects; WAL deltas explicitly include writer activity. Do not label either metric as migration-only bloat/WAL.

PostgreSQL 16 documentation: an `UPDATE` under Read Committed finds target rows committed at the command start; subsequent commands take fresh snapshots. This supports the snapshot-based hypothesis but does not replace querying the actual synthetic rows. Source: [transaction isolation](https://www.postgresql.org/docs/16/transaction-iso.html).

### Experiment 02 limits at the time of its first review

**NOT RUN as of Experiment 02:** 800 inserts/s, p99/attempt latency, multiple repetitions/order randomization, production schema/index widths, 120M-row scale, replica lag, actual production runner transaction behavior, retry/resume, partial failure, and direct currency verification of IDs 200002–200005. The hosted Actions allowance is also `UNKNOWN`. The observed runner snapshot (2 CPUs, roughly 7.75 GiB total memory, 13 GB free disk) does not establish capacity for the production-sized dataset. Experiment 03 later directly tests one controlled currency race; its evidence is in the section below.

### Review material submitted for draft commit `5c1a9a6` — attribution correction

**Provenance correction:** an earlier version of this report incorrectly attributed the code review and pre-run predictions to Nabiel personally. The later supplied note says that material came from an AI review. Correct status: AI-generated/AI-assisted review text was transmitted by Nabiel; authorship and any personal edits are unconfirmed. The review identifies script SHA-256 `15eb28b66ed6c86e0b85e23d54f5dc8b9fb2a027c961ecfd0c28e62ca88a533e` and workflow SHA-256 `d510486b51e289bcad668aa6ffd26b6af375c9373a62b2473a1db51f3d564995`, did not report an execution or file edit, and recommended **NO-GO** because observer matching likely failed on the multiline query. `REVIEWED_BY=Nabiel` in the later Actions run is a workflow input, not proof that a particular review text was personally authored. Do not count that AI review or its predictions as Nabiel's independent contribution.

**Pre-run prediction carried by that AI review text (not credited to Nabiel):** if the observer defect is fixed and the experiment is valid, `UPDATE` should report `100001` rows and take at least 3000 ms; id `200001` should end as EUR; id `200002` should remain USD; mismatch count should be 1; total rows should be 100002. The review text states the currency hypothesis is falsified if id `200002` is EUR or UPDATE reports 100002 rows. The revised harness uses a five-second synthetic pause and a `>=5000 ms` instrumentation check. It records actual values before classifying the hypothesis.

**Finding dispositions in the new, still-unrun revision:**

- **T-1:** observer now filters by the unique migration `application_name` and `wait_event='PgSleep'`; it does not assume a one-line query string. The query text is still emitted for inspection.
- **T-2/T-3:** script requires an active `PgSleep` observation before and after the insert and asserts the single measured UPDATE duration is at least 5000 ms. Start/commit and update-finished timestamps are logged.
- **T-4/T-5:** actual currency, mismatch, update-row, and total-row observations are printed before outcome classification. The result reports hypothesis supported/refuted/inconclusive; the script no longer emits a migration decision.
- **T-6:** output explicitly limits scope to per-statement autocommit with `ADD COLUMN` committed before `UPDATE`; it does not include rename or transaction-wrapped behavior.
- **T-7/T-8/T-9:** concurrent writer has 2 s `lock_timeout`, 5 s `statement_timeout`, and 8 s process timeout; script checks one parseable timing; runner log records `psql --version` and transaction isolation.

This revision remains **NOT RUN**. Bash syntax, YAML parsing, and the local safety guard are checked; no database was started locally. `actionlint` is unavailable. Nabiel must review the revised exact commit before dispatching the workflow. Its positive control and neutral hypothesis classification keep a falsifying result from being mislabeled as a failed harness. The synthetic pause remains instrumentation, not a performance measurement.

Do not increase scale until CI footprint, account cost/quota, timeout, and disk safety reserve are known. A separate load/latency experiment requires a declared target and measures p50/p95/p99, successful/failed attempts, and lock waits; Experiment 02's 25-attempt sequential probe cannot answer that question.

## Experiment 03 — controlled insert during backfill snapshot, 2026-10-29

**Provenance:** [Actions run 40866063966](https://github.com/nabielss/sscriticalai-week4/actions/runs/40866063966), attempt 1, commit `65a109ccf19138b6b05f496aed45ee1c7e071272`. Script SHA-256 `053f8bb3e849fff40a34561f8d704be4b87d8c392280192debf712b72261cbc9`; workflow SHA-256 `7604e46fab184377379bcde3edd2240723b05f6c1d62b2c900e171636e2b3572`. I recomputed both from `git show` at that commit. The supplied ZIP is preserved byte-for-byte at `evidence/experiment-03/40866063966/original-artifact.zip`; SHA-256 `FE5C932555F13C0D8068E151BF933B3B1B77D7AD6679E297CB13AC350DFA044C` matches the Actions upload digest. Its 14 files match the Actions upload count. Extracted files are in the sibling `received-extract/` directory. The accompanying text is preserved at `evidence/Run03-40866063966-pasted-log-and-interpretation.txt`; it includes the pasted Actions log and interpretation. Its prose authorship/AI assistance is not confirmed, so it is recorded as user-supplied, not as an independently authored Nabiel interpretation.

| Field | Value |
|---|---|
| SCRIPT_AUTHOR / TRIGGERED_BY / EXECUTED_ON | Codex / `nabielss` / GitHub-hosted Linux X64 (`1000000017`) |
| REVIEWED_BY / MANUAL_CHECK | Raw rig says `Nabiel` / `POST_RUN_REVIEW_PENDING`. A later supplied analysis reports manual artifact inspection, but its authorship is unconfirmed. |
| Data / database | 100,000 deterministic synthetic rows; PostgreSQL client/server 16.15; `read committed`; synthetic `DE/ID/US` distribution |
| Rig snapshot | 2 CPUs; MemTotal 8,122,984 kB; MemAvailable 7,165,400 kB; `/dev/root` 72 GB, 13 GB free. Actions account quota `UNKNOWN`. |
| Scope | Per-statement autocommit: `ADD COLUMN` committed before `UPDATE`; no rename; one pre-update DE control and one concurrent old-schema DE insert. A synthetic statement trigger pauses the update for 5 seconds; this is synchronization, not a performance model. |
| Exit | `SCRIPT_EXIT_STATUS=0`; 14 artifact files uploaded. This means harness checks completed, not that the migration is approved. |

**OBSERVED chronology:** observer output shows PostgreSQL backend PID 86 in `state=active`, `wait_event_type=Timeout`, `wait_event=PgSleep` at `11:32:00.313071Z`. The writer starts at `11:32:00.321217Z`; its psql call returns after `INSERT 0 1` at `11:32:00.372540Z`. A second observer query at `11:32:00.420987Z` still sees the same PID 86 paused in the same UPDATE. The UPDATE completes at `11:32:05.573431Z`. This brackets a successful committed insert between two observations of the same paused statement.

**OBSERVED result:** PostgreSQL reports `UPDATE 100001`, `Time: 5350.541 ms`, final rows `100002`, and script-queried values `pre_update_currency=EUR`, `concurrent_currency=USD`, `mismatches=1`. The EUR control was inserted before the UPDATE and confirms the backfill mapping works on the fixture. The concurrent DE row retained the new column's USD default. The `OBSERVED_RESULT` line is assembled by the script from SQL query results captured in shell variables; individual final `SELECT` stdout files were not retained separately. The source hash and raw summary are available, but that is a limitation in the granularity of raw SQL-output preservation.

**DERIVED:** the mismatch was caused in this controlled run by an insert committed after the UPDATE's statement snapshot was established and before its scan completed. The UPDATE count matches the 100,000 seed rows plus the pre-update control; the concurrent row was not included. This directly supports the mechanism hypothesized from Experiment 02. It does not show how many rows would be affected in production or how often a live insert falls in that window.

### Interpretation audit and limits

The supplied interpretation correctly narrows the result to one controlled 100k-row autocommit fixture on PostgreSQL 16.15, separates the Experiment 02 four-row currency inference from this direct run, and does not claim production frequency or scale. It also correctly distinguishes script-written labels such as `EXPERIMENT_FINDING=HYPOTHESIS_SUPPORTED` from independent evidence. Its authorship is not established, so the interpretation is retained as supplied analysis rather than credited as Nabiel-authored personal reasoning.

The result also sharpens the personal baseline: the earlier wording expected old inserts **after the UPDATE finishes** to receive USD. This run demonstrates that the suspected window starts earlier: a row committed after the UPDATE snapshot begins can be missed while the UPDATE is still active. Preserve the original baseline; record this as a later correction, not a rewritten baseline.

**NOT RUN:** 800 inserts/s, production-sized backfill/index/check, p99/latency, repeated runs, transaction-wrapped race, rename interaction, actual app driver/ORM behavior, other-country currency rules, replica lag, partial failure/retry/resume, or a mitigation. The five-second trigger makes the race deterministic but cannot estimate production exposure or migration duration. The hosted runner's 13 GB free disk is a startup snapshot, not evidence it can hold 120M rows/~180 GB. PostgreSQL docs for the snapshot rule: [Read Committed isolation](https://www.postgresql.org/docs/16/transaction-iso.html).

### Next gate

Do not repeat the same race run: it answered the narrow mechanism question. First, Nabiel must write a short independent interpretation in his own words (or confirm which parts of the supplied text he personally authored). Then complete the trainer's seven-part answer with observed/derived/unknown labels and a Plan B. Further CI work should be a separate, explicitly bounded gate for failure/resume or a measured lock/traffic question; 120M-row scale is unavailable on the observed standard runner and must stay `NOT RUN` unless a suitably sized, cost-approved runner is established.
