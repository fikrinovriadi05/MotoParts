import 'dart:async';

import 'package:motopart/core/location_service.dart';
import 'package:motopart/core/payment_api.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/core/report_exporter.dart';
import 'package:motopart/theme/app_theme.dart';

import 'support/fakes.dart';

/// Dijalankan otomatis untuk semua tes di folder ini.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Font Ahem (lebar) agar overflow cepat ketahuan; tanpa penundaan shimmer.
  UiConfig.useBrandFonts = false;
  UiConfig.simulateLoading = false;
  UiConfig.animate = false; // animasi interaksi dinyalakan per tes yang menguji
  // Tes tidak boleh memakai jaringan atau GPS sungguhan.
  PaymentMethods.demoOverride = false; // tes memakai server palsu, bukan demo
  paymentApi = FakePaymentApi();
  locationService = FakeLocationService();
  reportExporter = FakeReportExporter();
  await testMain();
}
