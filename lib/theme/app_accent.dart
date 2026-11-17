import 'package:flutter/material.dart';

/// Warna aksen yang bisa dipilih pengguna di Pengaturan Tampilan. Oranye
/// racing adalah warna merek MotoPart (bawaan).
enum AppAccent {
  orange('Oranye Racing', Color(0xFFFF6B00)),
  red('Merah', Color(0xFFE10600)),
  blue('Biru', Color(0xFF1E88E5)),
  green('Hijau', Color(0xFF2E7D32)),
  yellow('Kuning', Color(0xFFFFB300));

  final String label;
  final Color color;

  const AppAccent(this.label, this.color);

  /// Versi lebih terang untuk gradien dan aksen sekunder.
  Color get soft => Color.lerp(color, Colors.white, 0.22)!;

  /// Warna teks/ikon di atas [color] (charcoal atau putih, mana yang lebih
  /// kontras).
  Color get onColor {
    const dark = Color(0xFF1A1A1D);
    return contrastRatio(dark, color) >= contrastRatio(Colors.white, color)
        ? dark
        : Colors.white;
  }

  /// Warna aksen untuk teks/ikon kecil di atas [background]: diubah seperlunya
  /// (digelapkan atau diterangkan) sampai kontrasnya minimal [minContrast].
  Color readableOn(Color background, {double minContrast = 4.6}) {
    var c = color;
    final toward = background.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    for (var i = 0; i < 40 && contrastRatio(c, background) < minContrast; i++) {
      c = Color.lerp(c, toward, 0.04)!;
    }
    return c;
  }

  static AppAccent parse(String? name) => AppAccent.values.firstWhere(
    (a) => a.name == name,
    orElse: () => AppAccent.orange,
  );
}

/// Rasio kontras WCAG antara dua warna (1 sampai 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
