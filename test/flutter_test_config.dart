import 'dart:async';

import 'package:motopart/theme/app_theme.dart';

/// Dijalankan otomatis untuk semua tes di folder ini.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Tanpa jaringan: jangan unduh font; tanpa penundaan shimmer.
  UiConfig.useGoogleFonts = false;
  UiConfig.simulateLoading = false;
  await testMain();
}
