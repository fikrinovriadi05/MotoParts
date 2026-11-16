import 'package:flutter/material.dart';

/// Kelompok metode pembayaran. [providers] kosong berarti tidak perlu memilih
/// bank/dompet (mis. QRIS, COD).
class PaymentGroup {
  final String name;
  final IconData icon;
  final String description;
  final String providerLabel;
  final List<String> providers;

  /// Jenis di server pembayaran (`qris`, `va`, `ewallet`); null berarti tidak
  /// lewat server (COD: dibayar tunai saat barang tiba).
  final String? apiType;

  const PaymentGroup({
    required this.name,
    required this.icon,
    required this.description,
    this.providerLabel = '',
    this.providers = const [],
    this.apiType,
  });

  bool get hasProviders => providers.isNotEmpty;

  /// Dibayar online dan dicek otomatis oleh server.
  bool get isOnline => apiType != null;
}

/// Pilihan pembayaran: kelompok + bank/dompet (bila ada).
class PaymentChoice {
  final PaymentGroup group;
  final String? provider;

  const PaymentChoice(this.group, [this.provider]);

  /// Teks yang tampil dan disimpan di pesanan, mis. "Virtual Account - BCA".
  String get label =>
      provider == null ? group.name : '${group.name} - $provider';

  /// Bentuk singkat untuk disimpan di akun.
  String get encoded =>
      provider == null ? group.name : '${group.name}|$provider';

  bool get isOnline => group.isOnline;
  String? get apiType => group.apiType;

  /// Nama bank/dompet untuk server (huruf kecil), null untuk QRIS.
  String? get apiProvider => provider?.toLowerCase();

  @override
  bool operator ==(Object other) =>
      other is PaymentChoice &&
      other.group.name == group.name &&
      other.provider == provider;

  @override
  int get hashCode => Object.hash(group.name, provider);
}

class PaymentMethods {
  const PaymentMethods._();

  static const groups = [
    PaymentGroup(
      name: 'QRIS',
      icon: Icons.qr_code_2_rounded,
      description: 'Scan dengan aplikasi bank atau e-wallet',
      apiType: 'qris',
    ),
    PaymentGroup(
      name: 'Virtual Account',
      icon: Icons.receipt_long_rounded,
      description: 'Nomor virtual account, dicek otomatis',
      providerLabel: 'Pilih Bank',
      providers: ['BCA', 'Mandiri', 'BNI', 'BRI'],
      apiType: 'va',
    ),
    PaymentGroup(
      name: 'E-Wallet',
      icon: Icons.account_balance_wallet_outlined,
      description: 'Bayar dengan dompet digital (scan QR)',
      providerLabel: 'Pilih Dompet Digital',
      providers: ['GoPay'],
      apiType: 'ewallet',
    ),
    PaymentGroup(
      name: 'COD',
      icon: Icons.payments_outlined,
      description: 'Bayar tunai saat barang tiba',
    ),
  ];

  /// Pilihan awal jika pembeli belum menyimpan metode favorit.
  static PaymentChoice get defaultChoice => firstOf(groups.first);

  /// Pilihan pertama yang valid untuk [group] (bank pertama, atau tanpa bank).
  static PaymentChoice firstOf(PaymentGroup group) =>
      PaymentChoice(group, group.hasProviders ? group.providers.first : null);

  /// Membaca hasil [PaymentChoice.encoded]; `null` jika kosong atau tidak
  /// dikenal (mis. metode lama yang sudah dihapus dari daftar).
  static PaymentChoice? decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    final parts = encoded.split('|');
    final group = groups.where((g) => g.name == parts.first).firstOrNull;
    if (group == null) return null;
    if (!group.hasProviders) return PaymentChoice(group);
    final provider = parts.length > 1 ? parts[1] : null;
    if (provider == null || !group.providers.contains(provider)) return null;
    return PaymentChoice(group, provider);
  }
}
