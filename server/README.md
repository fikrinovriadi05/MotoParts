# Server pembayaran MotoPart

Server kecil (Dart + shelf) untuk pembayaran online: **QRIS**, **Virtual Account**
(BCA, Mandiri, BNI, BRI), dan **GoPay** lewat [Midtrans](https://docs.midtrans.com).
Aplikasi memanggil server ini; kunci rahasia Midtrans hanya ada di server, tidak
pernah di aplikasi.

## Menjalankan

```bash
cd server
dart pub get
dart run bin/server.dart
```

Tanpa pengaturan apa pun server berjalan di **mode simulasi**: tidak memakai
Midtrans, kode QR dan nomor VA hanya tiruan. Cocok untuk mencoba alur aplikasi.

| Variabel | Arti | Bawaan |
|---|---|---|
| `PORT` | Port server | `8080` |
| `MIDTRANS_SERVER_KEY` | Server Key Midtrans. **Kosong = mode simulasi** | kosong |
| `MIDTRANS_ENV` | `production` untuk Midtrans sungguhan | sandbox |
| `MOCK_AUTO_PAY_SECONDS` | Mode simulasi: otomatis lunas N detik setelah dibuat | mati |
| `QR_EXPIRY_MINUTES` | Batas bayar QRIS/GoPay | `15` |
| `VA_EXPIRY_MINUTES` | Batas bayar Virtual Account | `60` |
| `DATA_FILE` | Berkas penyimpanan pembayaran | `data/payments.json` |

Contoh (PowerShell):

```powershell
$env:MOCK_AUTO_PAY_SECONDS = "20"; dart run bin/server.dart          # simulasi, lunas otomatis
$env:MIDTRANS_SERVER_KEY = "SB-Mid-server-xxxx"; dart run bin/server.dart   # Midtrans Sandbox
```

### Mode simulasi

Lunasi pembayaran dengan:

```bash
curl -X POST http://localhost:8080/payments/<kode-pesanan>/simulate-paid
```

atau set `MOCK_AUTO_PAY_SECONDS`. Endpoint ini mati saat memakai Midtrans.

## Menghubungkan aplikasi

Alamat server bawaan aplikasi: emulator Android `http://10.0.2.2:8080`, platform
lain `http://localhost:8080`. Untuk alamat lain:

```bash
flutter run --dart-define=PAYMENT_API_URL=http://192.168.1.10:8080
flutter build apk --release --dart-define=PAYMENT_API_URL=https://bayar.contoh.com
```

- **Build debug** Android boleh HTTP ke alamat LAN mana pun (HP asli ke komputer).
- **Build rilis** hanya boleh HTTP ke emulator/localhost; alamat lain **wajib HTTPS**
  (lihat `android/app/src/main/res/xml/network_security_config.xml`).

## Memakai Midtrans Sandbox

1. Daftar di [dashboard.sandbox.midtrans.com](https://dashboard.sandbox.midtrans.com),
   ambil **Server Key** di Settings → Access Keys, lalu jalankan server dengan
   `MIDTRANS_SERVER_KEY`.
2. Aktifkan kanal QRIS, GoPay, dan Bank Transfer di Settings → Configuration
   / Payment bila belum aktif (error 402 = kanal belum aktif).
3. **Notifikasi otomatis (webhook, opsional)**: Midtrans hanya bisa memanggil alamat
   publik. Untuk uji lokal, jalankan tunnel (mis. `ngrok http 8080`) dan isi
   *Payment Notification URL* di Settings → Configuration dengan
   `https://<alamat-ngrok>/midtrans/notification`. Tanda tangan notifikasi
   diperiksa server. Tanpa webhook pun pembayaran tetap terdeteksi karena
   aplikasi mengecek status tiap 3 detik dan server menanyakannya ke Midtrans.
4. Bayar di sandbox lewat simulator Midtrans (bukan uang sungguhan):
   QRIS/GoPay `https://simulator.sandbox.midtrans.com/v2/qris/index`,
   BCA VA `.../bca/va/index`, BNI VA `.../bni/va/index`,
   BRI VA `.../openapi/va/index`. Docs: <https://docs.midtrans.com/docs/testing-payment-on-sandbox>.

## Endpoint

| Metode & jalur | Fungsi |
|---|---|
| `GET /health` | Cek server dan penyedia aktif |
| `POST /payments` | Buat pembayaran: `{id, type: qris\|va\|ewallet, provider?, amount, customerName?}` |
| `GET /payments/<id>` | Status (`pending`/`paid`/`failed`/`expired`); server mengeceknya ke Midtrans |
| `POST /payments/<id>/simulate-paid` | Hanya mode simulasi |
| `POST /midtrans/notification` | Webhook Midtrans (diverifikasi `signature_key`) |

`id` = kode pesanan aplikasi. Membuat ulang dengan data sama mengembalikan
pembayaran yang sama (aman bila koneksi putus saat membuat).

## Tes

```bash
cd server
dart test
```

## Batasan yang perlu diketahui

- **Belum diuji ke Midtrans sungguhan.** Bentuk permintaan/respons mengikuti
  dokumentasi Midtrans dan diuji dengan klien HTTP palsu. Dokumentasi hanya
  memberi contoh lengkap untuk QRIS; untuk VA, Mandiri (echannel), dan GoPay
  bentuk respons ditebak secara toleran (`va_numbers`, `bill_key`/`biller_code`,
  `actions`). Coba tiap kanal di sandbox sebelum dipakai.
- Rumus tanda tangan webhook memakai `gross_amount` persis seperti diterima
  (mis. `"55000.00"`); cocokkan dengan notifikasi sandbox pertama.
- **Jumlah pembayaran dipercaya dari aplikasi.** Katalog produk hanya ada di
  perangkat, jadi server tidak bisa menghitung ulang harga. Untuk produksi,
  pindahkan produk dan pesanan ke server.
- Server **tidak memiliki login pengguna**; siapa pun yang tahu alamatnya bisa
  membuat tagihan. Pasang di belakang autentikasi/HTTPS sebelum dipublikasikan.
- Penyimpanan berupa satu berkas JSON: cukup untuk satu server kecil, bukan
  untuk beban besar.
