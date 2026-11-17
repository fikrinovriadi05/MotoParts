import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan teks ke penyimpanan lokal tanpa pernah melempar. Penyimpanan
/// browser terbatas (sekitar 5 MB); jika penuh, penulisan gagal dengan
/// pengecualian yang tidak boleh merusak aplikasi (data di memori tetap utuh,
/// hanya tidak tersimpan permanen). Mengembalikan `false` jika gagal.
Future<bool> safeSetString(
  SharedPreferences prefs,
  String key,
  String value,
) async {
  try {
    return await prefs.setString(key, value);
  } on Object catch (error) {
    debugPrint('Gagal menyimpan "$key" (${value.length} karakter): $error');
    return false;
  }
}
