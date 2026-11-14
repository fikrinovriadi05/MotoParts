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
