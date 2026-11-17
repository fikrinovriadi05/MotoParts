# MotoPart

Aplikasi toko sparepart motor (Flutter). Pembeli bisa menelusuri katalog,
menyimpan wishlist, checkout, dan memantau pesanan; admin mengelola produk,
pesanan, pengguna, dan melihat laporan penjualan. Semua data tersimpan di
perangkat (belum ada server).

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
```

Sekitar 700 tes aplikasi (logika `Store`/`AuthStore`, halaman, overflow di layar
kecil, berkas ikon, font, pembayaran online, GPS, dan konfigurasi proyek) dan 35
tes server. Tes aplikasi memakai server pembayaran dan GPS palsu
(`test/support/fakes.dart`), jadi tidak memakai jaringan.

## Struktur singkat

| Folder | Isi |
|---|---|
| `lib/theme/` | Warna, ukuran, tema terang/gelap (`app_theme.dart`) |
| `lib/store/` | `Store` (produk, keranjang, pesanan, ulasan) dan `AuthStore` (akun) |
| `lib/pages/` | Halaman `auth/`, `user/`, `admin/`, `shared/` |
| `lib/widgets/` | Komponen bersama (kartu produk, logo, dll.) |
| `fonts/` | Inter (lisensi SIL OFL) |
| `server/` | Server pembayaran (Dart + shelf, Midtrans) |
| `tool/` | Pembuat ikon: `flutter test tool/generate_icons_test.dart` |

Panduan lengkap untuk agent pengembang ada di `.claude/agents/main-agent.md`.

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
- Keamanan akun hanya setara demo lokal (password di-hash dan disimpan di
  perangkat, tanpa server). Jangan dipakai untuk data pengguna sungguhan.
- Produk, pesanan, dan akun masih tersimpan di perangkat; hanya pembayaran yang
  lewat server. Server pembayaran belum punya login pengguna dan mempercayai
  jumlah dari aplikasi (lihat batasan di `server/README.md`) sehingga belum siap
  untuk uang sungguhan.
