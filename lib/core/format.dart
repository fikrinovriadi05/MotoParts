import 'package:intl/intl.dart';

final _rupiah = NumberFormat.decimalPattern('id_ID');

/// Format harga, contoh `Rp 125.000`.
String formatRupiah(int value) => 'Rp ${_rupiah.format(value)}';

const _bulan = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Contoh: `14 Nov 2026, 09:05`.
String formatTanggal(DateTime value) {
  final jam = value.hour.toString().padLeft(2, '0');
  final menit = value.minute.toString().padLeft(2, '0');
  return '${value.day} ${_bulan[value.month - 1]} ${value.year}, $jam:$menit';
}

/// Contoh: `14 Nov 2026`.
String formatTanggalSingkat(DateTime value) =>
    '${value.day} ${_bulan[value.month - 1]} ${value.year}';

const _hariLengkap = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const _bulanLengkap = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Contoh: `Selasa, 17 November 2026`.
String formatTanggalLengkap(DateTime value) =>
    '${_hariLengkap[value.weekday - 1]}, ${value.day} '
    '${_bulanLengkap[value.month - 1]} ${value.year}';

/// Salam menurut jam: pagi (sebelum 11), siang (sampai 15), sore (sampai 18),
/// selain itu malam.
String salamWaktu(DateTime now) {
  final h = now.hour;
  if (h < 4) return 'Selamat malam';
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 18) return 'Selamat sore';
  return 'Selamat malam';
}
