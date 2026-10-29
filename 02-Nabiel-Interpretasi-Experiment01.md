# Interpretasi Nabiel — Experiment 01

**Provenance:** ditulis dan dikirim Nabiel 2026-10-29 setelah membaca tiga log mentah dari run `40848098217`, sebelum audit ulang AI. Teks dipertahankan verbatim.

Kecil dan jelas isinya; saya ekstrak ke direktori kerja (bukan ke uploads) agar bisa dibaca.

## Interpretasi hasil Experiment 01

Saya membaca ketiga log mentahnya. File `old-query-after-rename.log` hanya salinan error yang sama dari `experiment-01.log`, jadi bukan bukti independen. Saya tidak melihat source `scripts/experiment-01.sh`, hanya outputnya.

### 1. Apa yang hasilnya buktikan

**`RENAME COLUMN` merusak query lama (risiko 2 terbukti).** Sebelum `up()`, `SELECT amount` berjalan. Setelah `COMMIT`, query yang sama gagal dengan `column "amount" does not exist`. Ini output asli Postgres 16.15, bukan klaim harness. Selama ±5 menit rolling deploy, pod lama pasti error kalau kodenya mereferensikan `amount`. Pembuktian ini tidak bergantung pada skala data, jadi 3 baris pun cukup.

**`down()` tidak "restore previous state" (klaim AI terbantah dua kali):**

- Nilai `currency` hilang. Setelah `down()`, kolom `currency` ada 0, termasuk override eksplisit `EUR` pada id 3 (`SNAPSHOT_BEFORE_DOWN` vs `currency_column_after_down=0`). Data `amount` utuh (sum 60.00), jadi yang hilang hanya informasi mata uang.
- Skema tidak identik dengan sebelum `up()`. `amount_nonneg` masih ada setelah `down()`. `down()` tidak pernah menghapusnya, dan `RENAME` tidak membuangnya.

Jadi "fully reversible" salah, baik soal data maupun soal skema.

### 2. Apa yang mengubah atau menguatkan baseline

| Prediksi/klaim baseline                    | Status                             | Catatan                                              |
| ------------------------------------------ | ---------------------------------- | ---------------------------------------------------- |
| Query `amount` gagal tepat setelah baris 6 | **Dikuatkan**                      | Pesan error persis seperti yang saya prediksi.       |
| `down()` bukan restore sejati              | **Dikuatkan, dengan satu koreksi** | Data currency hilang dan constraint tertinggal.      |
| Baris 2 metadata-only di PG ≥ 11           | **Konsisten, belum terbukti**      | Versi di rig 16.15, tapi tidak ada pengukuran waktu. |
| Lock di baris 5 dan 7, p99 insert melonjak | **Tidak diuji**                    | Lihat bagian 3.                                      |
| Baris INSERT pod lama dapat `'USD'` salah  | **Tidak diuji**                    | Perlu sesi insert bersamaan dengan `up()`.           |

**Koreksi atas baseline saya.** Saya menulis bahwa constraint dan index "tidak dibersihkan eksplisit". Constraint terbukti tertinggal. Untuk index, log tidak memeriksanya. Seingat saya, `DROP COLUMN currency` ikut menghapus index yang memuat kolom itu, jadi bagian "index tertinggal" kemungkinan salah. Itu masih dugaan dari pengetahuan umum, bukan dari log ini, dan perlu satu query ke `pg_indexes` untuk memastikannya.

**Konsekuensi praktis dari constraint yang tertinggal.** Kalau aplikasi lama pernah menulis `amount` negatif (refund, credit note), constraint itu akan menolaknya setelah rollback. Apakah pola itu ada, belum diketahui.

### 3. Apa yang belum dibuktikan

- **Risiko terbesar, soal lock, belum diuji.** Prediksi 1 saya (insert menumpuk dengan `wait_event_type='Lock'`, durasi naik linear terhadap jumlah baris) tidak terbantah maupun terkonfirmasi. Rig ini 3 baris, satu sesi, tanpa traffic. Ia membuktikan kerusakan logis, bukan dampak operasional.
- **Tidak ada pengukuran waktu atau skala.** Tidak ada angka untuk `UPDATE` 120M baris, build index, atau scan `CHECK`. Replica lag, WAL, dan bloat juga tidak disentuh.
- **Pembungkus transaksi adalah asumsi.** Log sendiri menulis "wrapped in one transaction (runner behavior unknown)". Kalau runner production berjalan tanpa transaksi, perilaku lock dan kegagalan parsial berbeda. Kalau satu transaksi, lock `ALTER TABLE` ditahan sampai commit, termasuk selama `UPDATE` dan `CREATE INDEX`, yang lebih buruk.
- **Query lama adalah query sintetis.** `SELECT amount ... WHERE id = 1` bukan query aplikasi sungguhan. Bahwa `INSERT` dari pod lama juga gagal masuk akal, tapi tidak dijalankan.
- **Versi production tidak diketahui.** Hasil PG 16.15 tidak otomatis berlaku di production.
- **Pemetaan `ELSE 'USD'` belum diuji.** Belum ada pengecekan negara non-DE/ID dengan mata uang lain.

### 4. Catatan tentang kualitas bukti

Script ditulis AI (Codex), dijalankan di GitHub Actions, dan `MANUAL_CHECK=POST_RUN_REVIEW_PENDING`. Itu berarti bukti ini belum punya penelaah independen. Baris `EXPERIMENT_HARNESS=PASS; MIGRATION_DECISION=REJECT` ditulis oleh script. Maknanya hanya bahwa harness mereproduksi defek yang ia cari, bukan bukti bahwa migration ditolak karena alasan yang benar. Bukti yang kuat di sini adalah error mentah Postgres dan angka snapshot sebelum/sesudah `down()`.

### Kesimpulan

Verdict TOLAK saya sekarang punya dua alasan yang terbukti: rename merusak pod lama dan `down()` tidak reversibel. Alasan ketiga, lock dan block insert di 120M baris, masih berupa penalaran. Eksperimen berikutnya yang paling berharga adalah dua sesi dengan `lock_timeout` pendek: satu menjalankan `up()` di tabel 1M, 5M, lalu 20M baris, satu lagi mencoba `INSERT` sambil membaca `pg_locks` dan `pg_stat_activity`. Itu yang akan menguji atau membantah prediksi 1.
