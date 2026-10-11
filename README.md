# Sistem Akuntansi Piutang & Angsuran – In House Financing

UTS Mata Kuliah Pengkodean dan Pemrograman - S1 Akuntansi

📌 Demo Aplikasi: 

Aplikasi berbasis web sederhana untuk mengelola dan mencatat transaksi piutang penjualan rumah dengan skema pembayaran *in-house financing* (angsuran langsung ke pengembang/developer).

---

## 🌟 Fitur Utama

- **Buku Besar Pembantu Piutang (Subsidiary Ledger):** Menampilkan daftar jadwal angsuran pelanggan beserta alokasi pembayaran pokok, bunga, total tagihan, dan status pelunasan.
- **Pencatatan Pembayaran Angsuran:** Form input transaksi pembayaran angsuran dengan nomor kwitansi otomatis dan jumlah bayar yang fleksibel.
- **Otomasi Status Pelunasan:** Menggunakan database trigger PostgreSQL untuk secara otomatis memperbarui status tagihan pada `jadwal_angsuran` menjadi **LUNAS** ketika transaksi pembayaran diinput.
- **Integrasi Real-time:** Terhubung langsung ke Supabase backend database via Supabase JS Client (CDN).

---

## 🛠️ Stack Teknologi

- **Frontend:** Vanilla HTML5, CSS3, JavaScript (ES6)
- **Backend / Database:** Supabase (PostgreSQL Database, Stored Procedures, & Triggers)
- **Deployment:** GitHub Pages

Proyek pembelajaran database: penjualan kredit dengan pembiayaan internal (bunga flat), jadwal angsuran, denda keterlambatan, dan jurnal akuntansi otomatis.

---

## Struktur folder

```
inhouse-financing-ar/
├── README.md
├── .gitignore
├── .vscode/extensions.json     # ekstensi yang disarankan
├── docs/
│   └── ERD.md                  # ERD (Mermaid), normalisasi, contoh jurnal
├── database/                   # jalankan berurutan di Supabase SQL Editor
│   ├── 01_schema.sql           # tabel, PK/FK, constraint, index
│   ├── 02_functions_triggers.sql  # create_contract, process_payment, trigger jurnal balance
│   ├── 03_views.sql            # kartu piutang, aging, neraca saldo, KPI
│   ├── 04_rls_policies.sql     # Row Level Security
│   └── 05_seed.sql             # bagan akun (wajib) + data contoh (opsional)
└── frontend/
    ├── index.html  customers.html  products.html
    ├── contracts.html  payments.html  reports.html
    ├── css/style.css
    └── js/
        ├── config.js           # URL & anon key Supabase  <-- ISI INI
        ├── supabaseClient.js   # inisialisasi client
        ├── utils.js            # format rupiah, tanggal, toast, modal
        ├── layout.js           # sidebar navigasi
        └── dashboard.js customers.js products.js
            contracts.js payments.js reports.js
```

---

## Cara menjalankan

1. **Supabase**: buat project di [supabase.com](https://supabase.com).
2. **SQL Editor**: jalankan `database/01` sampai `05` secara berurutan. (Hapus bagian B di `05_seed.sql` bila tidak ingin data contoh.)
3. Tidak perlu login/akun (mode belajar).
4. **Project Settings → API**: salin *Project URL* dan *anon public key* ke `frontend/js/config.js`.
5. **VS Code**: buka folder, pasang ekstensi *Live Server*, klik kanan `frontend/index.html` → *Open with Live Server*.
6. **GitHub**:
   ```bash
   git init && git add . && git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/<user>/inhouse-financing-ar.git
   git push -u origin main
   ```
   **Peringatan:** karena tanpa login, siapa pun yang tahu URL Supabase + anon key (terlihat di repo/halaman) bisa membaca dan mengubah data. Pakai hanya untuk data latihan. **Jangan** pernah menaruh `service_role` key di repo. Untuk hosting gratis, aktifkan GitHub Pages dari folder `/frontend` (atau deploy ke Netlify/Vercel).

---

## Alur kerja sistem

1. Input **Pelanggan** dan **Produk**.
2. **Kontrak Piutang** → `create_contract()` menghitung bunga flat, membuat jadwal angsuran, dan jurnal penjualan kredit.
3. **Pembayaran** → `process_payment()` menghitung denda, mengalokasikan ke angsuran tertua (denda → bunga → pokok), memperbarui status, dan membuat jurnal kas.
4. **Laporan**: umur piutang, neraca saldo, jurnal.

---

## Rumus

- Pokok pembiayaan = harga tunai − DP
- Total bunga = pokok × bunga%/tahun × tenor/12 (flat)
- Total piutang = pokok + bunga; angsuran = total piutang ÷ tenor (selisih pembulatan di angsuran terakhir)
- Denda = sisa tagihan × denda%/hari × hari terlambat

---

## Batasan (disengaja, untuk latihan)

- Sisa denda yang tidak terbayar tidak diakumulasi ke pembayaran berikutnya.
- Tidak ada fitur pembatalan pembayaran / pelunasan dipercepat dengan diskon bunga / hapus buku. Pembayaran & jurnal bersifat *append-only* (tidak bisa diubah lewat API).
- Tidak ada login/peran. Pengembangan lanjut: Supabase Auth + tabel `profiles` + peran admin/kasir di policy RLS.
- Jurnal contoh memakai persediaan dan modal awal fiktif di `05_seed.sql`.
