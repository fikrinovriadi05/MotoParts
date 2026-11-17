import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:motopart/core/remote_gateway.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';

/// Menyambungkan [Store] dan [AuthStore] ke database lewat [RemoteGateway].
///
/// Aplikasi memperbarui tampilan lebih dulu (optimis), mengirim perubahannya
/// ke server berurutan, lalu menarik data terbaru dari server (`GET /sync`)
/// sehingga yang tampil selalu sama dengan isi database.
class RemoteSync {
  const RemoteSync._();

  /// Pesan galat terakhir dari pengiriman ke server (ditampilkan sebagai
  /// snackbar oleh aplikasi). Null jika tidak ada.
  static final ValueNotifier<String?> error = ValueNotifier(null);

  static Future<void> _tail = Future.value();

  static bool get enabled => remoteGateway != null;

  /// Selesai setelah semua perubahan yang menunggu terkirim dan data terbaru
  /// ditarik (berguna untuk tes).
  static Future<void> get settled => _tail;

  /// Sinkronisasi pertama saat aplikasi dibuka: memulihkan sesi dari token dan
  /// memuat data. Tidak melempar; masalah jaringan dilaporkan lewat [error]
  /// (token disimpan agar sesi pulih saat server kembali), token yang ditolak
  /// membuat pengguna menjadi tamu.
  static Future<void> bootstrap({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!enabled) return;
    try {
      await pull().timeout(
        timeout,
        onTimeout: () => throw const RemoteException('Server tidak menjawab.'),
      );
    } on RemoteException catch (e) {
      if (e.isUnauthorized) {
        auth.sessionExpired();
        try {
          await pull();
        } on RemoteException catch (e2) {
          error.value = e2.message;
        }
      } else {
        error.value = e.message;
      }
    }
  }

  /// Menarik semua data dari server dan menerapkannya.
  static Future<void> pull() async {
    final gateway = remoteGateway;
    if (gateway == null) return;
    final json = await gateway.send('GET', '/sync');
    auth.applyRemoteSnapshot(json);
    store.applyRemoteSnapshot(json);
  }

  /// Menjalankan [op] setelah semua operasi sebelumnya selesai, lalu menarik
  /// data terbaru. Galat dilempar ke pemanggil.
  static Future<T> run<T>(Future<T> Function(RemoteGateway gateway) op) {
    final gateway = remoteGateway;
    if (gateway == null) {
      return Future.error(const RemoteException('Server belum diatur.'));
    }
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      T? result;
      Object? failure;
      StackTrace? failureTrace;
      try {
        result = await op(gateway);
      } catch (e, st) {
        failure = e;
        failureTrace = st;
      }
      // Tarik ulang walau gagal: tampilan optimis yang ditolak server kembali
      // ke keadaan sebenarnya. Pemanggil baru dilanjutkan setelah data terbaru
      // diterapkan.
      try {
        await pull();
      } on RemoteException catch (e) {
        if (e.isUnauthorized) auth.sessionExpired();
      }
      if (failure != null) {
        completer.completeError(failure, failureTrace);
      } else {
        completer.complete(result as T);
      }
    });
    return completer.future;
  }

  /// Seperti [run], tetapi tanpa menunggu: galat dilaporkan lewat [error].
  static void push(Future<void> Function(RemoteGateway gateway) op) {
    if (!enabled) return;
    unawaited(
      run(op).catchError((Object e) {
        error.value = e is RemoteException
            ? e.message
            : 'Perubahan tidak dapat dikirim ke server.';
      }),
    );
  }
}
