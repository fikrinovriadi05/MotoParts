import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web/index.html mematikan sorotan ketuk dan bingkai fokus biru', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('-webkit-tap-highlight-color'));
    expect(html, contains('outline: none'));
    // Berlaku untuk kanvas Flutter dan lapisan aksesibilitasnya.
    expect(html, contains('flt-glass-pane'));
    expect(html, contains('flt-semantics'));
    // Lapisan sorotan harus transparan, bukan warna lain.
    expect(html, contains('rgba(0, 0, 0, 0)'));
  });

  test(
    'web/index.html mencegah kanvas terseleksi (lapisan biru satu layar)',
    () {
      final html = File('web/index.html').readAsStringSync();

      expect(html, contains('user-select: none'));
      expect(html, contains('::selection'));
      expect(html, contains('background: transparent'));
    },
  );
}
