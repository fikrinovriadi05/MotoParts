import 'package:flutter/material.dart';

/// Kelompok metode pembayaran. [providers] kosong berarti tidak perlu memilih
/// bank/dompet (mis. COD).
class PaymentGroup {
  final String name;
  final IconData icon;
  final String description;
  final String providerLabel;
  final List<String> providers;

  const PaymentGroup({
    required this.name,
    required this.icon,
    required this.description,
    this.providerLabel = '',
    this.providers = const [],
  });

  bool get hasProviders => providers.isNotEmpty;
}

/// Pilihan pembayaran: kelompok + bank/dompet (bila ada).
class PaymentChoice {
  final PaymentGroup group;
  final String? provider;

  const PaymentChoice(this.group, [this.provider]);

  /// Teks yang tampil dan disimpan di pesanan, mis. "Transfer Bank - BCA".
  String get label =>
      provider == null ? group.name : '${group.name} - $provider';

  /// Bentuk singkat untuk disimpan di akun.
  String get encoded =>
      provider == null ? group.name : '${group.name}|$provider';

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
      name: 'Transfer Bank',
      icon: Icons.account_balance_rounded,
      description: 'Transfer manual ke rekening toko',
      providerLabel: 'Pilih Bank',
      providers: ['BCA', 'Mandiri', 'BNI', 'BRI'],
    ),
    PaymentGroup(
      name: 'E-Wallet',
      icon: Icons.account_balance_wallet_outlined,
      description: 'Bayar lewat dompet digital',
      providerLabel: 'Pilih Dompet Digital',
      providers: ['GoPay', 'OVO', 'DANA', 'ShopeePay'],
    ),
    PaymentGroup(
      name: 'Virtual Account',
      icon: Icons.receipt_long_rounded,
      description: 'Nomor virtual account khusus pesanan',
      providerLabel: 'Pilih Bank',
      providers: ['BCA', 'Mandiri', 'BNI', 'BRI'],
    ),
    PaymentGroup(
      name: 'COD',
      icon: Icons.payments_outlined,
      description: 'Bayar tunai saat barang tiba',
    ),
  ];

  /// Pilihan awal jika pembeli belum menyimpan metode favorit.
  static PaymentChoice get defaultChoice =>
      PaymentChoice(groups.first, groups.first.providers.first);

  /// Pilihan pertama yang valid untuk [group] (bank pertama, atau tanpa bank).
  static PaymentChoice firstOf(PaymentGroup group) =>
      PaymentChoice(group, group.hasProviders ? group.providers.first : null);

  /// Membaca hasil [PaymentChoice.encoded]; `null` jika kosong atau tidak
  /// dikenal (mis. daftar metode berubah di versi baru).
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
