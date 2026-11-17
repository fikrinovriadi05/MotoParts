import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motopart/app.dart';
import 'package:motopart/core/product_image_storage.dart';
import 'package:motopart/core/remote_gateway.dart';
import 'package:motopart/store/remote_sync.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lisensi font (SIL OFL) tampil di halaman lisensi aplikasi.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Inter',
    ], await rootBundle.loadString('fonts/OFL-Inter.txt'));
  });
  final prefs = await SharedPreferences.getInstance();
  await themeController.attach(prefs);
  await store.attach(prefs);
  await auth.attach(prefs); // setelah store: memulihkan sesi login
  if (ApiConfig.enabled) {
    // Mode database: foto produk disimpan di database (bukan berkas lokal),
    // lalu ambil data terbaru dari server.
    DeviceProductImageStorage.storeInline = true;
    await RemoteSync.bootstrap();
  }
  runApp(const MotoPartApp());
}
