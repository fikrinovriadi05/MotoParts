import 'dart:async';

import 'package:motopart/theme/app_theme.dart';

/// Dijalankan otomatis untuk semua tes di folder ini.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Font Ahem (lebar) agar overflow cepat ketahuan; tanpa penundaan shimmer.
  UiConfig.useBrandFonts = false;
  UiConfig.simulateLoading = false;
  await testMain();
}
