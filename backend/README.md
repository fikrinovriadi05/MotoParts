# MotoPart – Backend (PHP + MySQL)

API REST untuk aplikasi MotoPart. Semua data (akun, alamat, produk, pesanan,
ulasan, wishlist) disimpan di database **MySQL/MariaDB**. Cocok untuk XAMPP
dan hosting biasa (PHP 8.1+ dengan ekstensi `pdo_mysql`).

## Menjalankan di XAMPP (lokal)

1. Buka XAMPP Control Panel, jalankan **Apache** dan **MySQL**.
2. Salin folder `backend` ke `C:\xampp\htdocs\motopart-api`
   (atau jalankan server bawaan PHP, lihat bawah).
3. Buat database dan isi data awal:

   ```
   C:\xampp\php\php.exe C:\xampp\htdocs\motopart-api\tool\setup.php
   ```

   Perintah ini membuat database `motopart`, semua tabel, akun admin, dan 12
   produk + 2 pesanan contoh. Aman diulang. `--reset` menghapus semuanya dan
   mengisi ulang.
4. Cek di browser: <http://localhost/motopart-api/health> → `{"status":"ok",...}`.
5. Jalankan aplikasi dengan alamat API:

   ```
   flutter run --dart-define=API_URL=http://localhost/motopart-api
   ```

   Emulator Android memakai `http://10.0.2.2/motopart-api`.

Tanpa PHP-Apache: `php -S 0.0.0.0:8081 index.php` di folder `backend`, lalu
`API_URL=http://localhost:8081`.

## Akun bawaan

| Peran | Email | Password |
|-------|-------|----------|
| Admin | `admin@motopart.id` | `admin123` |

Ganti password admin dari aplikasi (Akun → Ganti Password), atau ubah
`admin_password` di `config.local.php` **sebelum** menjalankan `setup.php`.
Pengguna biasa mendaftar sendiri lewat aplikasi.

## Konfigurasi

Bawaan (`config.php`) cocok untuk XAMPP: `127.0.0.1:3306`, user `root`, tanpa
password, database `motopart`. Untuk hosting, salin `config.example.php` menjadi
`config.local.php` lalu isi data MySQL dari penyedia hosting (berkas ini
tidak ikut git). Alternatif: variabel lingkungan `MOTOPART_DB_HOST`,
`MOTOPART_DB_PORT`, `MOTOPART_DB_NAME`, `MOTOPART_DB_USER`, `MOTOPART_DB_PASS`.

Di hosting: unggah isi folder `backend`, buat database lewat panel (phpMyAdmin),
impor `database/schema.sql`, lalu jalankan `tool/setup.php` lewat terminal
hosting — atau cukup impor `schema.sql` dan daftarkan admin lewat phpMyAdmin.
Set `allow_origin` ke alamat web aplikasi bila ingin membatasi CORS.

## Struktur database

`database/schema.sql`: `users`, `sessions`, `addresses`, `products`, `orders`,
`order_items`, `reviews`, `wishlists`. Waktu disimpan UTC; password memakai
bcrypt; sesi berupa token acak 64 heks (berlaku 30 hari).

## Endpoint

Semua berbentuk JSON. Kesalahan: `{"error": "pesan"}` dengan status HTTP yang
sesuai. Token dikirim lewat header `Authorization: Bearer <token>`.

| Metode & alamat | Akses | Keterangan |
|-----------------|-------|------------|
| `GET /health` | publik | Cek server + database |
| `GET /sync` | publik / masuk | Semua data untuk pengguna ini sekaligus |
| `POST /auth/register` | publik | Daftar → `{token, user}` |
| `POST /auth/login` | publik | `{email, password, role: user\|admin}` |
| `POST /auth/logout` | masuk | Cabut token |
| `GET /me`, `PUT /me` | masuk | Profil, data motor, metode bayar favorit |
| `PUT /me/password` | masuk | Ganti password |
| `POST /addresses`, `PUT/DELETE /addresses/{id}`, `PUT /addresses/{id}/default` | masuk | Alamat pengiriman |
| `GET /products` | publik | Daftar produk |
| `POST /products`, `PUT/DELETE /products/{id}` | admin | Kelola produk |
| `GET /orders` | masuk | Pesanan sendiri (admin: semua) |
| `POST /orders` | masuk | Checkout: stok dikunci & dipotong dalam transaksi; harga diambil dari database |
| `PUT /orders/{code}/status` | admin (pembeli: hanya pesanannya yang menunggu bayar) | Ubah status; batal mengembalikan stok |
| `GET /reviews`, `POST /reviews` | publik / pembeli pesanan Selesai | Ulasan |
| `DELETE /reviews/{productId}/{userId}` | admin | Hapus ulasan |
| `GET /wishlist`, `PUT/DELETE /wishlist/{productId}` | masuk | Wishlist |
| `GET /users`, `PUT /users/{id}/password` | admin | Daftar pengguna, reset password |
| `POST /admin/reset-sample-data` | admin | Kembalikan data contoh |

## Tes

```
powershell -ExecutionPolicy Bypass -File backend\tests\run.ps1
```

Skrip ini menyalakan MariaDB **sementara** (port 3307, folder data sementara)
dan server PHP, menjalankan 100 tes API, lalu mematikan dan menghapusnya.
Database XAMPP Anda tidak disentuh.
