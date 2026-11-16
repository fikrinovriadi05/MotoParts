import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pilihan tampilan pengguna: ikut sistem, terang, atau gelap. Tersimpan di
/// perangkat.
class ThemeController extends ValueNotifier<ThemeMode> {
  static const storageKey = 'motopart_theme_mode';

  SharedPreferences? _prefs;

  ThemeController() : super(ThemeMode.system);

  Future<void> attach(SharedPreferences prefs) async {
    _prefs = prefs;
    final saved = prefs.getString(storageKey);
    value = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  void setMode(ThemeMode mode) {
    value = mode;
    _prefs?.setString(storageKey, mode.name);
  }
}

final ThemeController themeController = ThemeController();
