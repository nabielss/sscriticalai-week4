# Baseline awal Nabiel — sebelum diagnosis AI

**Provenance:** teks ditulis oleh Nabiel dan diterima 2026-10-29 sebelum diagnosis lengkap. Disimpan verbatim; tidak diedit atau dilengkapi oleh AI.

Baseline awal (sebelum diagnosis lengkap)
1) Verdict awal: TOLAK. Migration ini tidak aman dijalankan di production seperti klaim AI. "1,8 detik di staging" tidak membuktikan apa-apa, karena staging punya 500k baris (240x lebih kecil), tanpa traffic, dan hanya satu pod. Klaim "zero downtime", "reversible", dan "aman jam kerja" menurut saya semuanya salah atau tidak terbukti.
2) Tiga risiko yang saya duga:
1. Lock dan operasi seluruh tabel (baris 3, 5, 7). CREATE INDEX tanpa CONCURRENTLY menahan lock yang memblokir INSERT selama build di 120M baris, sehingga 800 insert/detik akan menumpuk dan app hang. ADD CONSTRAINT CHECK tanpa NOT VALID memindai seluruh tabel sambil menahan lock berat. UPDATE 120M baris dalam satu transaksi menghasilkan bloat, banjir WAL, dan replica lag yang membuat dashboard ikut bermasalah.
2. RENAME COLUMN (baris 6) merusak pod lama. Selama ±5 menit rolling deploy, pod lama masih mengakses amount, yang sudah tidak ada. Hasilnya error di production dan di dashboard replica. Ini pelanggaran pola expand/contract.
3. Data salah dan rollback palsu (baris 2-4, 10-13). Baris yang di-INSERT pod lama setelah UPDATE selesai mendapat default 'USD', padahal seharusnya EUR atau IDR. ELSE 'USD' juga memetakan semua negara non-DE non-ID ke USD, padahal mungkin ada negara eurozone lain. down() membuang kolom currency beserta datanya, jadi tidak benar-benar "restore". Constraint dan index juga tidak dibersihkan eksplisit.
3) Prediksi eksperimen yang bisa dibantah:
Saya siapkan Postgres lokal dengan data sintetis (misalnya 20-50 juta baris, skema sama, tanpa data asli). Saya jalankan pgbench custom yang melakukan INSERT ±800 TPS, lalu up() secara bersamaan. Prediksi saya:
- Saat baris 5 dan 7 berjalan, pg_stat_activity menunjukkan sesi INSERT dengan wait_event_type = 'Lock', dan p99 latency insert melonjak dari milidetik menjadi detik atau menit. Durasinya naik kira-kira linear terhadap jumlah baris.
- Query lama SELECT amount FROM invoices gagal dengan column "amount" does not exist tepat setelah baris 6.
- Baris 2 sendiri cepat (metadata-only) kalau Postgres ≥ 11, jadi angka 1,8 detik di staging mayoritas berasal dari tabel yang kecil, bukan dari keamanan skrip.
Prediksi ini salah jika: p99 insert tetap di bawah ±100 ms tanpa Lock wait selama seluruh up(), dan query amount tetap jalan. Kalau itu terjadi, saya harus merevisi risiko 1 dan 2.
Catatan asumsi: versi Postgres production belum diketahui. Kalau < 11, baris 2 pun menjadi full table rewrite dan risikonya lebih parah. Ini harus dikonfirmasi lewat SELECT version() di staging dan di production oleh tim yang berwenang.
