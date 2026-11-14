String formatRupiah(int value) {
  final text = value.toString();
  final result = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    result.write(text[i]);
    final remaining = text.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      result.write('.');
    }
  }
  return 'Rp$result';
}

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
