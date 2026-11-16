import 'package:flutter/foundation.dart';

/// Indeks tab di `UserShell`.
class UserTab {
  static const home = 0;
  static const category = 1;
  static const cart = 2;
  static const account = 3;
}

/// Tab aktif di halaman pembeli. Dipakai agar bagian lain aplikasi (mis.
/// SnackBar "Lihat" atau tombol "Mulai Belanja") bisa berpindah tab.
final ValueNotifier<int> userTabIndex = ValueNotifier<int>(UserTab.home);
