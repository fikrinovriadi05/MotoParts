# MotoPart

Aplikasi toko sparepart motor (Flutter). Pembeli bisa menelusuri katalog,
menyimpan wishlist, checkout, dan memantau pesanan; admin mengelola produk,
pesanan, pengguna, dan melihat laporan penjualan.

Data bisa disimpan di dua tempat:

- **Database MySQL** (disarankan; wajib untuk tugas): lewat backend PHP di
  folder `backend/`. Lihat bagian [Database](#database-mysql) di bawah.
- **Lokal di perangkat** (bawaan bila `API_URL` tidak diatur): dipakai untuk
  mencoba cepat dan oleh semua tes.

## Menjalankan

```bash
flutter pub get
flutter run -d <perangkat>        # mis. emulator Android atau Chrome
```

Akun admin bawaan: `admin@motopart.id`. Password awalnya ada di
`AuthStore.adminInitialPassword`; **ganti segera** lewat Dashboard Admin.
Pembeli mendaftar sendiri di layar Daftar, lalu bisa melengkapi data motor
(nama, tipe, tahun), alamat pengiriman, dan metode pembayaran favorit di menu
Akun.

## Database (MySQL)

Semua data (akun, alamat, produk, pesanan, ulasan, wishlist) disimpan di MySQL
lewat API PHP di `backend/` (detail, daftar endpoint, dan cara pasang di hosting:
`backend/README.md`). Dengan XAMPP:

1. Nyalakan **Apache** dan **MySQL** di XAMPP, salin `backend/` ke
   `C:\xampp\htdocs\motopart-api`.
2. Buat database + data awal: `C:\xampp\php\php.exe C:\xampp\htdocs\motopart-api\tool\setup.php`
3. Jalankan aplikasi dengan alamat API:

   ```bash
   flutter run --dart-define=API_URL=http://localhost/motopart-api      # Chrome/desktop
   flutter run --dart-define=API_URL=http://10.0.2.2/motopart-api       # emulator Android
   ```

Cara kerjanya: aplikasi memperbarui tampilan lebih dulu, mengirim perubahan ke
server berurutan, lalu menarik data terbaru (`GET /sync`) sehingga tampilan
selalu sama dengan isi database. Checkout dilakukan di server dalam transaksi
(stok dikunci, harga dari database). Password di-hash bcrypt di server dan
aplikasi hanya menyimpan token sesi. Keranjang tetap di perangkat. Foto produk
disimpan di database sebagai data URL. Tanpa `API_URL`, aplikasi berjalan
lokal seperti sebelumnya.

Admin bawaan: `admin@motopart.id` / `admin123` (ganti dari menu Akun).

## Panel admin

Login admin lewat tab **Admin** di layar masuk. Menu: **Dashboard**, **Produk**,
**Pesanan**, **Kategori**, **Pengaturan**. Di HP berupa bilah navigasi bawah;
di layar lebar (> 900) berupa sidebar di kiri (dengan logo dan nama admin).
Halaman admin tidak bisa dibuka tanpa login admin.

- **Dashboard**: sapaan menurut jam + tanggal, kartu Total Produk, Pesanan Hari
  Ini, Pendapatan, dan Stok Menipis (di bawah 5), grafik penjualan 7 hari,
  daftar stok menipis (ketuk untuk mengedit), dan 5 pesanan terbaru.
- **Produk**: cari + filter kategori, stok cepat dengan tombol - / +, form
  tambah/edit sebagai halaman penuh (foto dari galeri **atau URL gambar** dengan
  pratinjau, chip tipe motor yang cocok), hapus dengan tombol Urungkan. Gambar
  dari URL dimuat saat ditampilkan; jika alamatnya salah atau situsnya
  melarang, tampil ikon produk.
- **Pesanan**: filter status, ubah status, detail pesanan.
- **Kategori**: tambah, ubah nama/ikon, **seret untuk mengurutkan** (urutan juga
  dipakai di beranda pembeli), hapus (ditolak bila masih dipakai produk;
  mengganti nama ikut memindahkan produknya).
- **Pengaturan**: tampilan, laporan penjualan, pengguna, ganti password, reset
  data contoh, dan keluar (dengan konfirmasi).

Catatan database: fitur Kategori memakai tabel baru `categories`. Jika Anda
sudah memasang backend sebelumnya, jalankan ulang `tool/setup.php` (aman
diulang) agar tabel dan kategori bawaan dibuat.

## Tema dan warna aksen

Menu Akun (pembeli) dan Pengaturan admin punya **Pengaturan Tampilan**: mode
Terang / Gelap / Sistem, lima warna aksen (Oranye Racing bawaan, Merah, Biru,
Hijau, Kuning), dan kartu pratinjau yang langsung berubah. Pilihan tersimpan di
perangkat dan berlaku untuk seluruh aplikasi (sisi pembeli dan admin). Teks di
atas aksen dan teks beraksen otomatis disesuaikan agar tetap terbaca di mode
terang maupun gelap.

## Laporan penjualan dan ekspor Excel

Admin: Dashboard > Laporan Penjualan. Pilih periode lewat chip **Semua**,
**7 Hari**, **30 Hari**, **Bulan Ini**, atau **Pilih Tanggal** (rentang bebas);
total, rata-rata, barang terjual, dan grafik per hari mengikuti periode itu.

Tombol **Ekspor ke Excel (.xlsx)** menyimpan periode terpilih sebagai buku kerja
Excel dengan tiga lembar yang tertata rapi (judul berwarna, header, garis tabel,
lebar kolom, format Rupiah dan tanggal, baris total, status berwarna):
**Ringkasan**, **Per Produk**, dan **Pesanan**. Angka disimpan sebagai angka
sehingga bisa langsung dijumlahkan atau dibuat grafik. Di web berkas langsung
terunduh; di Android dan desktop muncul lembar berbagi (simpan ke Drive/Files,
kirim lewat email, dll.).

## Pembayaran online (QRIS, Virtual Account, GoPay)

Pembayaran QRIS, Virtual Account (BCA/Mandiri/BNI/BRI), dan GoPay dibuat lewat
**server pembayaran** di folder [`server/`](server/README.md) (Dart + shelf,
memakai Midtrans). Aplikasi menampilkan kode QR atau nomor VA, lalu mengecek
status otomatis tiap 3 detik; saat lunas pesanan berubah dari *Menunggu
Pembayaran* menjadi *Diproses*, dan jika waktu habis pesanan dibatalkan dan stok
dikembalikan. COD tidak lewat server.

```bash
cd server && dart run bin/server.dart     # mode simulasi, tanpa akun Midtrans
flutter run                                # emulator Android memakai http://10.0.2.2:8080
```

Tanpa server berjalan, hanya COD yang bisa dipakai. Pengaturan Midtrans Sandbox,
webhook, dan batasan ada di [`server/README.md`](server/README.md).

## Filter sparepart berdasarkan tipe motor

Di **Katalog**, pilih *Pilih tipe motor* (atau pintasan *Motor saya* dari data
akun) untuk hanya menampilkan sparepart yang cocok: yang khusus motor itu lebih
dulu, lalu yang untuk jenisnya (mis. "Honda Matic" untuk Honda Beat), lalu yang
universal (bisa dimatikan lewat chip *Termasuk universal*). Kecocokan dibaca
dari kolom **Tipe Motor** produk, jadi admin mengisinya dengan nama motor
dipisah koma (mis. `Honda Beat, Honda Vario`) atau `Universal`.

Pintasan lain: kolom pencarian **Beranda** ikut mengenali tipe motor (mengetik
"Beat" menemukan produk Honda Beat dan Honda Matic, lalu menawarkan
*Semua sparepart untuk ...* ke Katalog), dan menu **Sparepart untuk Motor Saya**
di halaman Akun langsung membuka Katalog yang sudah difilter.

## Lokasi GPS untuk alamat

Di form alamat, tombol **Gunakan Lokasi Saya (GPS)** mengambil koordinat lalu
mengisi alamat otomatis lewat OpenStreetMap Nominatim (perlu internet). Hasilnya
bisa diedit sebelum disimpan, dan titik GPS ikut tersimpan di alamat dan pesanan.

## Tes dan pemeriksaan

```bash
flutter analyze
flutter test
cd server && dart analyze && dart test
powershell -ExecutionPolicy Bypass -File backend\tests\run.ps1 -E2E
```

Sekitar 860 tes aplikasi (logika `Store`/`AuthStore`, halaman, overflow di layar
kecil, berkas ikon, font, pembayaran online, GPS, mode database, dan konfigurasi
proyek) dan 35 tes server. Tes aplikasi memakai server pembayaran, GPS, dan
server database palsu (`test/support/fakes.dart`, `test/remote_test.dart`),
jadi tidak memakai jaringan.

Perintah terakhir menyalakan MariaDB **sementara** (bukan database XAMPP Anda)
dan server PHP, lalu menjalankan 100 tes API dan satu tes ujung ke ujung
(`test/server_e2e_test.dart`: aplikasi melawan database sungguhan).

## Struktur singkat

| Folder | Isi |
|---|---|
| `lib/theme/` | Warna, ukuran, tema terang/gelap (`app_theme.dart`) |
| `lib/store/` | `Store` (produk, keranjang, pesanan, ulasan), `AuthStore` (akun), `RemoteSync` (sinkron ke database) |
| `backend/` | API PHP + MySQL (`database/schema.sql`, `src/`, `tests/`) |
| `lib/pages/` | Halaman `auth/`, `user/`, `admin/`, `shared/` |
| `lib/widgets/` | Komponen bersama (kartu produk, logo, dll.) |
| `fonts/` | Inter (lisensi SIL OFL) |
| `server/` | Server pembayaran (Dart + shelf, Midtrans) |
| `tool/` | Pembuat ikon: `flutter test tool/generate_icons_test.dart` |

Panduan lengkap untuk agent pengembang ada di `.claude/agents/main-agent.md`.

## Versi web (untuk dibagikan lewat link)

Aplikasi bisa dibuka di browser. Bangun dengan satu perintah:

```powershell
powershell -ExecutionPolicy Bypass -File tool/build_web.ps1
```

Hasilnya `build/web` (folder situs) dan `build/motopart-web.zip` (sekitar 15 MB,
siap diunggah). Mencoba di komputer sendiri:

```bash
cd build/web && python -m http.server 8080     # buka http://localhost:8080
```

**Menerbitkan agar punya link** (pilih salah satu, semuanya gratis):

1. **Netlify (paling mudah):** buka <https://app.netlify.com/drop>, seret folder
   `build/web` (atau zip-nya). Anda langsung mendapat link `https://....netlify.app`.
2. **GitHub Pages:** unggah repositori ke GitHub, lalu *Settings -> Pages ->
   Source: GitHub Actions*. Workflow `.github/workflows/web.yml` menjalankan tes
   dan menerbitkan otomatis setiap push ke `main`
   (link: `https://<pengguna>.github.io/<nama-repo>/`).
3. **Firebase Hosting:** `firebase init hosting` (folder publik `build/web`,
   single-page: tidak perlu), lalu `firebase deploy`.

Jika situs berada di subfolder (mis. GitHub Pages), beri `-BaseHref /nama-repo/`
pada skrip build.

**Perbedaan di web**

- Data (akun, produk, pesanan) tersimpan di **browser tiap pengunjung**
  (localStorage): akun yang dibuat di satu browser tidak terlihat di browser lain,
  dan menghapus data situs menghapus semuanya. Akun admin bawaan selalu ada.
- Pembayaran **hanya COD**. QRIS/Virtual Account/GoPay butuh server pembayaran
  yang bisa dijangkau dari internet; beri `-PaymentApi https://alamat-server`
  saat membangun jika sudah punya.
- Foto produk disimpan di browser dan dibatasi **350 KB** per foto
  (total penyimpanan browser sekitar 5 MB, jadi kira-kira belasan foto).
- Tombol GPS butuh situs berprotokol **HTTPS** dan izin lokasi dari browser;
  jika ditolak, alamat diisi manual.
- Kunjungan pertama mengunduh sekitar 40 MB tanpa kompresi (dikompres server
  hosting), jadi layar pemuatan tampil beberapa detik.
- Efek hover (kursor mouse) aktif di versi web/desktop.

## Logo dan ikon

Logo digambar lewat kode (`lib/widgets/brand_mark.dart`). Semua ikon dan
gambar splash (Android, iOS, macOS, web, Windows) dibuat ulang dengan:

```bash
flutter test tool/generate_icons_test.dart
```

## Build rilis Android

Nama paket: `id.motopart.app`.

1. Buat kunci penandatanganan **sekali saja** (simpan cadangannya di tempat
   aman; jika hilang, aplikasi tidak bisa diperbarui di Play Store):

   ```bash
   keytool -genkeypair -v -keystore android/app/motopart-release.jks \
     -alias motopart -keyalg RSA -keysize 2048 -validity 10000 -storetype PKCS12
   ```

2. Buat `android/key.properties` (berkas ini dan `*.jks` sudah di-ignore git,
   jangan pernah di-commit):

   ```properties
   storePassword=<sandi keystore>
   keyPassword=<sandi kunci>
   keyAlias=motopart
   storeFile=motopart-release.jks
   ```

3. Bangun:

   ```bash
   flutter build apk --release          # untuk dipasang langsung
   flutter build appbundle --release    # untuk diunggah ke Play Store
   ```

Tanpa `key.properties`, build rilis memakai kunci debug (hanya untuk uji,
tidak bisa diunggah ke Play Store).

### Versi

Atur `version: 1.0.0+1` di `pubspec.yaml` (angka setelah `+` adalah kode
versi yang harus naik di setiap rilis ke Play Store).

## Catatan

- Font disertakan di dalam aplikasi (tanpa unduhan). Izin internet dipakai
  hanya untuk server pembayaran dan pencarian alamat dari GPS; izin lokasi hanya
  diminta saat tombol GPS ditekan.
- Font: iOS/macOS memakai San Francisco bawaan sistem; Android, Windows, dan
  Linux memakai Inter (mirip San Francisco). San Francisco tidak disertakan
  di aplikasi karena lisensi Apple hanya mengizinkannya di platform Apple.
- Keamanan akun setara demo/tugas: password di-hash bcrypt di server, tetapi API
  belum memakai HTTPS (di hosting nyalakan HTTPS) dan belum membatasi percobaan
  login. Jangan dipakai untuk data pengguna sungguhan.
- Pada pembayaran online, status "lunas" masih dilaporkan oleh aplikasi ke
  database (server database belum menerima notifikasi/webhook dari Midtrans),
  dan server pembayaran mempercayai jumlah dari aplikasi (lihat
  `server/README.md`). Belum siap untuk uang sungguhan.
