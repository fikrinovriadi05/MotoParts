import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motopart/app.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lisensi font (SIL OFL) tampil di halaman lisensi aplikasi.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Poppins',
    ], await rootBundle.loadString('fonts/OFL-Poppins.txt'));
    yield LicenseEntryWithLineBreaks([
      'Montserrat',
    ], await rootBundle.loadString('fonts/OFL-Montserrat.txt'));
  });
  final prefs = await SharedPreferences.getInstance();
  await themeController.attach(prefs);
  await store.attach(prefs);
  await auth.attach(prefs); // setelah store: memulihkan sesi login
  runApp(const MotoPartApp());
}
