import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Penyimpanan pembayaran: di memori, dan ke berkas JSON bila [file] diberi
/// (agar data tetap ada setelah server dihidupkan ulang).
class PaymentRepository {
  final File? file;
  final _items = <String, Payment>{};

  PaymentRepository({this.file}) {
    final f = file;
    if (f == null || !f.existsSync()) return;
    try {
      final list = jsonDecode(f.readAsStringSync()) as List;
      for (final e in list) {
        final p = Payment.fromJson(e as Map<String, dynamic>);
        _items[p.id] = p;
      }
    } on Object {
      // Berkas rusak: mulai dari kosong.
    }
  }

  Payment? find(String id) => _items[id];

  Iterable<Payment> get all => _items.values;

  void save(Payment payment) {
    _items[payment.id] = payment;
    final f = file;
    if (f == null) return;
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(
      jsonEncode(_items.values.map((p) => p.toJson()).toList()),
    );
  }
}
