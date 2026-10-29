# Week 4 — diagnosis dan desain eksperimen pertama

Status: dua CI correctness run sudah selesai (Run 01 `both`, Run 02 `rollback`); lock/traffic/scale tetap `NOT RUN`. Ini belum submission final.

## Provenance

- `CHALLENGE FACT`: brief Challenge 4, disalin di [ChallengeWeek4.md](ChallengeWeek4.md).
- `TRAINER FACT`: laporan trainer Week 3 p.13–14 dan p.20, direkonsiliasi di `audit/05-Week3-Trainer-Style-Report.md` dan `audit/06-Week4-8-Playbook.md`.
- `USER BASELINE`: [Baseline-User.md](Baseline-User.md), ditulis Nabiel sebelum diagnosis; dipertahankan verbatim.
- `DOCUMENTED`: dokumentasi PostgreSQL resmi yang ditautkan pada bagian sumber.
- `DERIVED`: hitungan/inferensi yang ditandai demikian.
- `HYPOTHESIS`/`UNKNOWN`: klaim yang butuh uji atau konfirmasi owner.
- `OBSERVED`: dua rehearsal correctness pada tiga row sintetis; raw run cards dan limitations ada di [review evidence](03-Evidence-Review-Experiment01.md).
- `NOT RUN`: seeding skala, traffic, lock contention, WAL/replica, partial failure, resume/recovery, atau pengukuran waktu/scale.

## Fakta challenge dan batasnya

**CHALLENGE FACT:** `up()` otomatis jalan sebelum versi aplikasi baru rollout. Enam pod lama terus melayani saat rolling deploy kira-kira lima menit. Production disebut 120 juta invoice/~180 GB termasuk indeks, puncak 800 insert/detik, app dan dashboard read replica membaca sepanjang hari. Staging sekitar 500 ribu baris, tanpa traffic, satu pod. `120M / 500k = 240x` adalah `DERIVED` hanya untuk jumlah baris; rasio ukuran, waktu, dan perilaku lock tidak bisa disimpulkan darinya.

**UNKNOWN:** versi Postgres production/staging, migration runner dan apakah seluruh `up()` dibungkus transaksi, skema/index/ukuran baris aktual, hardware/IOPS/disk bebas/WAL, isolation level, replica topology/settings, aplikasi mana yang membaca `amount`, pemetaan mata uang yang sah, serta SLA/ambang “no visible downtime”. Tidak ada bukti raw dari klaim 1,8 s.

## Audit klaim AI dan baseline Nabiel

| Klaim / baris | Mekanisme dan penilaian | Label, apa yang diperlukan |
|---|---|---|
| “Tested on staging: 1.8 s, no errors” | Hanya melaporkan satu hasil pada staging tanpa workload dan ukuran yang berbeda. Tanpa script, seed, versi, hardware, lock/latency/WAL/replica metrics, dan raw log, itu tidak dapat direplikasi atau digeneralisasi. | `CLAIMED`, bukan `OBSERVED` di artefak ini. Perlu rig/data/command/output lengkap. |
| “Zero downtime” | Baris 6 mengganti nama `amount` sebelum app baru mulai rollout. Begitu perubahan commit terlihat, pod lama yang masih meminta `amount` akan menerima error kolom tidak ada. Lima menit coexistence adalah fakta challenge; pemanggilan kolom lama adalah asumsi kuat yang harus dibuktikan dari kode/traffic atau diuji. DDL juga dapat membuat permintaan menunggu lock. | `DERIVED` bersyarat + `HYPOTHESIS`; skenario old-app query adalah falsifier langsung. |
| “Fully reversible” | Baris 11 menghapus `currency`; baris 12 mengembalikan nama kolom jumlah. Nilai currency yang ditulis/diubah setelah migration tidak dipertahankan. Untuk baris hasil backfill, country mungkin cukup untuk menghitung ulang hanya jika pemetaan tetap benar dan tidak pernah ada override; brief tidak menjamin hal itu. Baris 7 menambah constraint yang tidak dihapus oleh `down()`, sehingga schema juga tidak identik dengan awal. Index yang bergantung pada kolom `currency` otomatis ikut hilang saat kolom di-drop; ketiadaan `DROP INDEX` eksplisit bukan defect tersendiri. | Klaim reversibility tidak terbukti dan makna data currency bersifat lossy. Perlu kontrol nilai sebelum `down()` dan pemeriksaan schema/data sesudahnya. |
| “Safe during business hours” | Tidak ada evidence traffic, lock wait, throughput, p95/p99, WAL/disk, dampak replica, timeout/cancel, atau recovery. “No visible downtime” tidak dapat dibuktikan oleh run idle 500k. | `OVERCLAIM`; perlu rehearsal sintetis bertahap dan ambang yang disepakati, bukan ekstrapolasi linear. |

### Per line

- **L2:** `DEFAULT 'USD' NOT NULL` memberi nilai USD untuk baris lama secara logis dan untuk insert baru yang tidak menyebut currency. Pada Postgres 11+ default konstan umumnya metadata-only; sebelum 11 penambahan kolom dengan default melakukan rewrite. Keduanya tetap butuh lock DDL dan durasinya bergantung keadaan. Versi production belum diketahui. Sumber resmi: [ALTER TABLE](https://www.postgresql.org/docs/current/sql-altertable.html).
- **L3–4:** backfill memetakan `DE→EUR`, `ID→IDR`, semua selain itu (termasuk `NULL`) ke USD. Kesesuaian mapping dengan aturan finance tidak diketahui. Satu `UPDATE` tanpa batching/checkpoint memperbarui banyak tuple; biaya WAL, dead tuples/bloat, vacuum debt, I/O/CPU, ruang disk dan replica lag harus diukur. Snapshot update dapat melewatkan insert yang terjadi setelah statement snapshot; `DEFAULT USD` membuat correctness insert paralel perlu diuji. Ini bukan bukti bahwa UPDATE sendiri selalu menahan lock tabel eksklusif yang memblokir semua insert.
- **L5:** `CREATE INDEX` non-concurrent melakukan scan/build dan memblokir write selama build (read tetap bisa), sehingga insert dapat menunggu. Durasi bukan dijamin linear terhadap row count. `CREATE INDEX CONCURRENTLY` mengubah lock/write impact tetapi memerlukan lebih banyak kerja, beberapa scan/wait, bisa meninggalkan index invalid saat gagal, dan tidak boleh dijalankan di transaction block. Runner transaction behavior harus diketahui sebelum memilih rencana. Sumber: [CREATE INDEX](https://www.postgresql.org/docs/current/sql-createindex.html).
- **L6:** rename adalah ketidakcocokan kontrak selama rollout bila old pods memakai `amount`; dashboard di replica terdampak hanya bila query dashboard mereferensikan nama lama (belum diketahui). Rename sendiri metadata operation, tetapi lock menunggu transaksi lain dan dapat membuat antrean.
- **L7:** `CHECK (total_amount >= 0)` memindai tabel untuk memvalidasi existing rows; dokumentasi menyebut perubahan lain pada tabel terkunci sampai ADD CONSTRAINT commit. Lock level `ALTER TABLE` umumnya `ACCESS EXCLUSIVE` kecuali didokumentasikan lebih ringan. `NOT VALID` lalu `VALIDATE` dapat mengubah fase scan/lock, tetapi tetap harus dirancang dan diuji. Constraint currency/valid mapping tidak ada. Sumber: [ALTER TABLE](https://www.postgresql.org/docs/current/sql-altertable.html).
- **L10–13:** `down()` menghapus currency dan mengubah nama kembali. Constraint bernama `amount_nonneg` tetap ada dan otomatis mengikuti kolom yang di-rename; data currency sendiri di-drop. Jangan memakai down sebagai recovery plan sebelum membuktikan apa yang terjadi pada invoice yang sudah ditulis.

### Koreksi baseline pribadi

Baseline Anda tepat dalam menolak klaim tanpa bukti, menyoroti old-pod rename break, default USD/currency mapping, dan kehilangan currency saat `down()`. Tiga klaim perlu dipersempit sebelum dijadikan kesimpulan:

1. **Lock:** L5 memang pasti mengunci writer selama index build biasa. L7 melakukan scan dan memblokir update sampai commit. L3–4 menghasilkan write/WAL besar, tetapi “UPDATE menahan lock tabel yang memblokir insert” belum benar sebagai klaim umum. Transaksi pembungkus dapat memperpanjang lock DDL hingga commit.
2. **Skala/linearitas:** 20–50 juta rows local bertentangan dengan kebijakan eksekusi Anda. Ubah menjadi eksperimen itu di GitHub-hosted Actions bila kapasitas/disk runner terukur cukup; jangan menganggapnya akan muat. Hubungan waktu tidak boleh diprediksi linear.
3. **Postgres version:** kemungkinan rewrite pada <11 adalah relevan, tetapi belum diketahui apakah environment memakai versi itu. Uji versi yang tercatat, jangan mengasumsikan produksi sama dengan staging atau `postgres:16`.

P99 spike dan `wait_event_type='Lock'` adalah falsifiable metric yang baik untuk ronde traffic nanti. Ia tidak membuktikan semua risk 1/2 salah hanya dari satu syarat gabungan: gunakan metrik terpisah untuk L5, L7, dan old-query compatibility. Untuk prediksi low-cost pertama, query old app setelah rename seharusnya gagal; kontrol sebelum rename harus lolos.

## Eksperimen 1 — dua falsifier kecil, hanya GitHub-hosted Actions

**Tujuan:** bukan membuktikan aman; membuktikan harness mengenali dua sifat yang membuat migration ini tidak layak dinyatakan rolling-safe/reversible. Hanya fixture sintetis kecil, tidak ada staging atau data/credential production.

### A. Old-app compatibility

1. Buat schema minimal `invoices(id, country, amount, created_at)` dengan data sintetis positif.
2. **Positive control:** jalankan query aplikasi lama `SELECT amount ...`; wajib berhasil dan mengembalikan row/amount yang diharapkan.
3. Jalankan `up()` yang persis dari brief.
4. Kontrol baru: baca `total_amount` dan `currency`; hasil harus sesuai fixture.
5. Jalankan query aplikasi lama yang sama. **Expected finding:** gagal khusus karena kolom `amount` tidak ada. Jika gagal karena sebab lain, eksperimen invalid, bukan sukses.

### B. `down()` dan currency

1. Di schema terpisah/di-reset, jalankan `up()` dan verifikasi fixture synthetic menyimpan EUR untuk DE dan IDR untuk ID (positive control).
2. Uji satu invoice synthetic dengan currency eksplisit yang tidak bisa diturunkan dari country, sebagai asumsi falsifier yang ditandai dalam log.
3. Catat nilai amount/currency sebelum rollback; jalankan `down()`.
4. Assert `amount` tersedia dan nilainya sama; assert `currency` tidak ada. Catat sebagai **gate gagal: nilai currency tidak dipertahankan oleh down()**, bukan mengklaim seluruh nilai backfill mustahil direkonstruksi dari country.

### Harness pass/fail dan provenance

- Workflow input memberi Nabiel pilihan menjalankan `compatibility`, `rollback`, atau `both` terlebih dahulu; kedua skenario wajib selesai sebelum gate eksperimen 1 ditutup. Field `reviewed_by` wajib diisi setelah Nabiel membaca script/workflow. Expected output markers: `old_query_before_rename=PASS`; `new_query_after_up=PASS`; `old_query_after_rename=EXPECTED_ERROR: column amount does not exist`; `currency_before_down=PASS`; `amount_after_down=PASS`; `currency_after_down=ABSENT`; `rollback_currency_gate=FAIL`.
- CI job boleh selesai dengan harness sukses bila kedua defect terdeteksi tepat dan positive controls lulus. Ringkasan job harus menyatakan **migration ditolak**; green job hanya berarti harness berhasil mereproduksi defect, bukan approval migration. Marker yang salah/missing harus membuat job gagal.
- Simpan raw stdout/stderr dan exit code, bahkan bila job gagal; upload artifact pada `if: always()`.
- Run card wajib isi: `SCRIPT_AUTHOR`, `TRIGGERED_BY`, `EXECUTED_ON`, `REVIEWED_BY`, `MANUAL_CHECK`, commit SHA, URL/job/attempt, tanggal & zona waktu, Postgres image/version, CPU/RAM/disk hasil ukur, seed/row count, command, artifact path, exit status, limitations. `MANUAL_CHECK` tetap `POST_RUN_REVIEW_PENDING` sampai Nabiel menulis cek dan interpretasinya setelah membaca artifact.
- **Status sekarang:** compatibility gate diuji pada Run 01 (`99b21a4`); rollback gate diuji pada Run 01 dan Run 02 (`a579dc1`). Run 02 menemukan index count 0 setelah `down()`, tetapi belum memiliki positive-control index count sebelum `down()`. Perubahan script sekarang menambah guard target, pre/post index inspection, file hashes, dan upload log yang tersinkron; seluruh perubahan itu masih `NOT RUN`.

## GitHub Actions kapasitas dan biaya: fakta dokumentasi vs pengukuran

- **DOCUMENTED, bukan hasil run:** dokumentasi GitHub saat ini menyebut standard Linux runner private repo (`ubuntu-24.04`/`ubuntu-latest`) 2 vCPU, 8 GB RAM, 14 GB SSD. Usable space lebih kecil setelah image/OS/service. [Runner labels/specs](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax).
- **DOCUMENTED, akun/kuota belum diketahui:** GitHub Free menyertakan 2.000 menit/bulan dan 500 MB storage; Pro 3.000 menit dan 1 GB; private runner minutes dan artifact storage dapat ditagih melewati allowance. Workflow perlu batas waktu dan artifact retensi/ukuran. [Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions).
- **DERIVED:** dataset produksi ~180 GB tidak muat pada runner private standard yang dokumentasinya mencantumkan 14 GB SSD. Itu bukan pernyataan tentang larger runner atau runner lain, tetapi larger runner tidak diasumsikan gratis/tersedia.
- **UNKNOWN:** plan/remaining allowance/spend cap pada akun Nabiel dan resource yang benar-benar terlihat oleh job. Catat saat workflow pertama berjalan sebelum menaikkan skala. Scale ladder baru dipilih dari pengukuran aktual; 120M/~180GB tetap `NOT RUN`/di luar kapasitas standard runner.

## Gate berikutnya

**Gate correctness sudah dilewati dengan batasan di atas. Gate berikutnya:** Nabiel meninjau revisi script/workflow terkini dan memicu `workflow_dispatch` untuk memverifikasi positive control index dan provenance baru, atau langsung menyetujui desain Experiment 02 setelah review. Experiment 02 akan menguji lock dengan writer pada runner Actions, dimulai dari fixture kalibrasi dan scale-up hanya jika disk headroom terukur mencukupi. Setelah itu barulah kandidat diuji; belum ada fix yang dijalankan.
