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

## Tes dan pemeriksaan

```bash
flutter analyze
flutter test
```

Sekitar 450 tes (logika `Store`/`AuthStore`, halaman, overflow di layar kecil,
berkas ikon, font, dan konfigurasi proyek).

## Struktur singkat

| Folder | Isi |
|---|---|
| `lib/theme/` | Warna, ukuran, tema terang/gelap (`app_theme.dart`) |
| `lib/store/` | `Store` (produk, keranjang, pesanan, ulasan) dan `AuthStore` (akun) |
| `lib/pages/` | Halaman `auth/`, `user/`, `admin/`, `shared/` |
| `lib/widgets/` | Komponen bersama (kartu produk, logo, dll.) |
| `fonts/` | Inter (lisensi SIL OFL) |
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

- Aplikasi berjalan offline: font disertakan di dalam aplikasi, tidak perlu
  izin internet.
- Font: iOS/macOS memakai San Francisco bawaan sistem; Android, Windows, dan
  Linux memakai Inter (mirip San Francisco). San Francisco tidak disertakan
  di aplikasi karena lisensi Apple hanya mengizinkannya di platform Apple.
- Keamanan akun hanya setara demo lokal (password di-hash dan disimpan di
  perangkat, tanpa server). Jangan dipakai untuk data pengguna sungguhan.
