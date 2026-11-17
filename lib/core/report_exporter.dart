import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:motopart/core/report_download_stub.dart'
    if (dart.library.js_interop) 'package:motopart/core/report_download_web.dart';
import 'package:share_plus/share_plus.dart';

/// Hasil mengekspor berkas.
enum ExportResult {
  /// Berkas diunduh/dibagikan.
  done,

  /// Pengguna menutup lembar berbagi tanpa memilih tujuan.
  cancelled,
}

/// Kesalahan saat mengekspor, dengan pesan yang bisa ditampilkan.
class ExportException implements Exception {
  final String message;

  const ExportException(this.message);

  @override
  String toString() => message;
}

/// Menyimpan/membagikan berkas teks (CSV). Diabstraksikan agar bisa diganti
/// di tes (tanpa lembar berbagi sungguhan).
abstract class ReportExporter {
  Future<ExportResult> saveCsv({
    required String fileName,
    required String content,
  });
}

class DeviceReportExporter implements ReportExporter {
  static const mimeType = 'text/csv';

  @override
  Future<ExportResult> saveCsv({
    required String fileName,
    required String content,
  }) async {
    try {
      if (kIsWeb) {
        // Web: unduh langsung ke folder Downloads browser.
        downloadTextFile(fileName, content, mimeType);
        return ExportResult.done;
      }
      // Android/iOS/desktop: lembar berbagi sistem (simpan ke Drive/Files,
      // kirim lewat WhatsApp/email, dll.).
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(content),
              mimeType: mimeType,
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
          subject: 'Laporan Penjualan MotoPart',
        ),
      );
      return result.status == ShareResultStatus.dismissed
          ? ExportResult.cancelled
          : ExportResult.done;
    } on Object catch (e) {
      if (e is ExportException) rethrow;
      throw const ExportException(
        'Laporan tidak dapat diekspor di perangkat ini.',
      );
    }
  }
}

/// Pengekspor yang dipakai aplikasi (bisa diganti di tes).
ReportExporter reportExporter = DeviceReportExporter();
