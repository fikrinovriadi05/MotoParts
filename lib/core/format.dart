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
