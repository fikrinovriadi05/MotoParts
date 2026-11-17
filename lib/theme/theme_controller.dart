import 'package:flutter/material.dart';
import 'package:motopart/theme/app_accent.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pilihan tampilan pengguna: mode (ikut sistem, terang, gelap) dan warna
/// aksen. Tersimpan di perangkat.
///
/// Nilai [ValueNotifier] ini adalah mode; warna aksen ada di [accent].
class ThemeController extends ValueNotifier<ThemeMode> {
  static const storageKey = 'motopart_theme_mode';
  static const accentKey = 'motopart_theme_accent';

  SharedPreferences? _prefs;

  /// Warna aksen terpilih (bawaan oranye racing).
  final ValueNotifier<AppAccent> accent = ValueNotifier(AppAccent.orange);

  ThemeController() : super(ThemeMode.system);

  /// Berubah saat mode atau warna aksen berubah.
  Listenable get changes => Listenable.merge([this, accent]);

  Future<void> attach(SharedPreferences prefs) async {
    _prefs = prefs;
    final saved = prefs.getString(storageKey);
    value = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
    accent.value = AppAccent.parse(prefs.getString(accentKey));
  }

  void setMode(ThemeMode mode) {
    value = mode;
    _prefs?.setString(storageKey, mode.name);
  }

  void setAccent(AppAccent color) {
    accent.value = color;
    _prefs?.setString(accentKey, color.name);
  }
}

final ThemeController themeController = ThemeController();
