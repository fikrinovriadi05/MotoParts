import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:motopart/core/safe_save.dart';
import 'package:motopart/models/app_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pusat notifikasi di dalam aplikasi. Disimpan terpisah dari `Store` (dan di
/// perangkat, juga di mode database) supaya status "sudah dibaca" bertahan.
class NotificationStore extends ChangeNotifier {
  static const storageKey = 'motopart_notifications_v1';

  /// Penerima khusus: notifikasi untuk admin toko (bukan satu akun).
  static const adminAudience = '@admin';

  /// Batas notifikasi per akun; yang paling lama dibuang.
  static const maxPerAccount = 100;

  SharedPreferences? _prefs;
  final List<AppNotification> _items = [];
  int _counter = 0;

  Future<void> attach(SharedPreferences prefs) async {
    _prefs = prefs;
    final raw = prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      _items
        ..clear()
        ..addAll(list);
    } catch (_) {
      // Data rusak: mulai dari kosong.
    }
    super.notifyListeners();
  }

  @override
  void notifyListeners() {
    final prefs = _prefs;
    if (prefs != null) {
      unawaited(
        safeSetString(
          prefs,
          storageKey,
          jsonEncode(_items.map((e) => e.toJson()).toList()),
        ),
      );
    }
    super.notifyListeners();
  }

  /// Notifikasi milik [accountId], yang terbaru di atas.
  List<AppNotification> forAccount(String accountId) =>
      _items.where((n) => n.accountId == accountId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int unreadCount(String accountId) =>
      _items.where((n) => n.accountId == accountId && !n.read).length;

  void add({
    required String accountId,
    required String title,
    required String body,
    String? orderCode,
    String? status,
    DateTime? now,
  }) {
    _items.add(
      AppNotification(
        id: '${DateTime.now().microsecondsSinceEpoch}-${_counter++}',
        accountId: accountId,
        title: title,
        body: body,
        createdAt: now ?? DateTime.now(),
        orderCode: orderCode,
        status: status,
      ),
    );
    // Buang yang terlama jika melebihi batas.
    final mine = forAccount(accountId);
    for (final old in mine.skip(maxPerAccount)) {
      _items.remove(old);
    }
    notifyListeners();
  }

  void markRead(AppNotification notification) {
    if (notification.read) return;
    notification.read = true;
    notifyListeners();
  }

  void markAllRead(String accountId) {
    var changed = false;
    for (final n in _items) {
      if (n.accountId == accountId && !n.read) {
        n.read = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void clear(String accountId) {
    _items.removeWhere((n) => n.accountId == accountId);
    notifyListeners();
  }

  /// Isi notifikasi untuk perubahan status pesanan [code] menjadi [status].
  /// [from] = status sebelumnya (null = pesanan baru dibuat).
  static (String title, String body) orderMessage(
    String code,
    String status, {
    String? from,
  }) {
    if (from == null) {
      return status == 'Menunggu Pembayaran'
          ? (
              'Menunggu pembayaran',
              'Pesanan $code sudah dibuat. Selesaikan pembayaran sebelum '
                  'tagihan kedaluwarsa.',
            )
          : (
              'Pesanan berhasil dibuat',
              'Pesanan $code diterima dan segera diproses.',
            );
    }
    return switch (status) {
      'Diproses' when from == 'Menunggu Pembayaran' => (
        'Pembayaran diterima',
        'Pembayaran pesanan $code berhasil. Pesananmu sedang diproses.',
      ),
      'Diproses' => ('Pesanan diproses', 'Pesanan $code sedang diproses.'),
      'Dikemas' => ('Pesanan dikemas', 'Pesanan $code sedang dikemas.'),
      'Dikirim' => (
        'Pesanan dikirim',
        'Pesanan $code dalam perjalanan ke alamatmu.',
      ),
      'Selesai' => (
        'Pesanan selesai',
        'Pesanan $code telah selesai. Beri penilaian untuk barang yang '
            'kamu beli.',
      ),
      'Dibatalkan' => ('Pesanan dibatalkan', 'Pesanan $code dibatalkan.'),
      _ => ('Status pesanan berubah', 'Pesanan $code kini $status.'),
    };
  }
}

final NotificationStore notifications = NotificationStore();
