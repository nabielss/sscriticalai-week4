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

**Still NOT RUN:** old-app `INSERT (amount)` after rename; concurrent traffic/lock measurement; scale/backfill/WAL/replica impact; partial failure/resume; and production migration-runner behavior. The harness wraps both `up()` and `down()` in transactions, while the real runner behavior is unknown. Run 03 establishes correctness defects on a three-row PostgreSQL 16.15 fixture, not production timing or lock impact.

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

No candidate fix has been implemented or tested. Before Experiment 02, add the old-app `INSERT (amount)` assertion because it is a direct gap identified in Nabiel's review. Then prepare the bounded CI lock experiment; Nabiel chooses and triggers the CI run. Preserve the `down()` findings; do not run rollback as a production recovery recommendation.
