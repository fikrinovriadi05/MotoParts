import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/core/payment_api.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/models/payment_info.dart';
import 'package:motopart/pages/user/payment_success_page.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/status_badge.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Menunggu pembayaran online (QRIS, Virtual Account, GoPay). Status dicek
/// otomatis ke server secara berkala; saat lunas langsung pindah ke halaman
/// sukses, dan saat kedaluwarsa pesanan dibatalkan.
class PaymentWaitingPage extends StatefulWidget {
  final String orderCode;

  /// Selang pengecekan otomatis.
  final Duration pollInterval;

  /// Jam sekarang (diganti di tes).
  final DateTime Function() clock;

  const PaymentWaitingPage({
    super.key,
    required this.orderCode,
    this.pollInterval = const Duration(seconds: 3),
    this.clock = DateTime.now,
  });

  @override
  State<PaymentWaitingPage> createState() => _PaymentWaitingPageState();
}

class _PaymentWaitingPageState extends State<PaymentWaitingPage> {
  Timer? _poll;
  Timer? _tick;
  late DateTime _now = widget.clock();
  bool _checking = false;
  bool _manualChecking = false;
  bool _leaving = false;

  /// Pesan jika server tidak bisa dihubungi (pengecekan dicoba lagi sendiri).
  String? _connectionError;

  OrderItem? get _order => store.orderByCode(widget.orderCode);

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(widget.pollInterval, (_) => _check());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = widget.clock());
    });
    // Langsung periksa sekali, tanpa menunggu selang pertama.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  /// Pindah ke halaman sukses jika pesanan sudah dibayar (mis. lewat pengecekan
  /// di halaman lain).
  void _goToSuccessIfPaid() {
    final order = _order;
    if (_leaving || !mounted || order == null) return;
    if (order.status == Store.awaitingPaymentStatus ||
        order.status == Store.cancelledStatus) {
      return;
    }
    _leaving = true;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
      (route) => route.isFirst,
    );
  }

  Future<void> _check({bool manual = false}) async {
    final order = _order;
    final payment = order?.payment;
    if (_checking || order == null || payment == null) return;
    if (order.status != Store.awaitingPaymentStatus) {
      _goToSuccessIfPaid();
      return;
    }

    _checking = true;
    if (manual && mounted) setState(() => _manualChecking = true);
    try {
      final snapshot = await paymentApi.status(payment.paymentId);
      if (!mounted) return;
      _connectionError = null;
      switch (snapshot.status) {
        case PaymentStatus.paid:
          store.markOrderPaid(order);
          _poll?.cancel();
          _goToSuccessIfPaid();
        case PaymentStatus.failed:
        case PaymentStatus.expired:
          store.cancelUnpaidOrder(order);
          _poll?.cancel();
        case PaymentStatus.pending:
          if (manual) _snack('Pembayaran belum diterima.');
      }
    } on PaymentApiException catch (e) {
      if (!mounted) return;
      _connectionError = e.message;
      if (manual) _snack(e.message);
    } finally {
      _checking = false;
      if (mounted) setState(() => _manualChecking = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goHome() {
    userTabIndex.value = UserTab.home;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const UserShell()),
      (route) => false,
    );
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    _snack('$label disalin.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menunggu Pembayaran')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final order = _order;
          final payment = order?.payment;
          if (order == null || payment == null) {
            return const Center(child: Text('Pesanan tidak ditemukan.'));
          }

          final cancelled = order.status == Store.cancelledStatus;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _goToSuccessIfPaid(),
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  _header(context, order, payment),
                  const SizedBox(height: AppSpacing.lg),
                  if (cancelled)
                    _cancelledCard(context)
                  else ...[
                    _paymentDetails(context, payment),
                    const SizedBox(height: AppSpacing.lg),
                    _autoCheckNote(context),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      text: _manualChecking
                          ? 'Memeriksa...'
                          : 'Cek Status Pembayaran',
                      icon: Icons.refresh_rounded,
                      onPressed: _manualChecking
                          ? null
                          : () => _check(manual: true),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      text: 'Bayar Nanti',
                      outline: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                  if (cancelled) ...[
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      text: 'Kembali ke Beranda',
                      icon: Icons.home_rounded,
                      onPressed: _goHome,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Nama bank/dompet seperti di daftar metode ("gopay" -> "GoPay").
  static String? _providerName(String? provider) {
    if (provider == null) return null;
    for (final group in PaymentMethods.groups) {
      for (final name in group.providers) {
        if (name.toLowerCase() == provider.toLowerCase()) return name;
      }
    }
    return provider;
  }

  String _countdown(DateTime expiresAt) {
    final left = expiresAt.difference(_now);
    if (left.isNegative) return '00:00';
    String two(int n) => n.toString().padLeft(2, '0');
    final h = left.inHours;
    final m = left.inMinutes.remainder(60);
    final s = left.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  Widget _header(BuildContext context, OrderItem order, PaymentInfo payment) {
    final palette = context.palette;
    final expires = payment.expiresAt;
    final waiting = order.status == Store.awaitingPaymentStatus;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: palette.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(order.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Total Pembayaran', style: TextStyle(color: palette.textMuted)),
          Text(
            formatRupiah(order.total),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: palette.primaryText,
            ),
          ),
          if (order.paymentMethod != null) ...[
            const SizedBox(height: 2),
            Text(
              order.paymentMethod!,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
          ],
          if (waiting && expires != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: palette.primaryText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Bayar dalam ${_countdown(expires)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: palette.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cancelledCard(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cancel_rounded, color: palette.dangerText),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Waktu pembayaran habis atau pembayaran ditolak, sehingga '
              'pesanan dibatalkan dan stok dikembalikan. Silakan pesan ulang.',
              style: TextStyle(
                color: palette.dangerText,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _autoCheckNote(BuildContext context) {
    final palette = context.palette;
    final error = _connectionError;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: error == null
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.wifi_off_rounded,
                  size: 16,
                  color: palette.dangerText,
                ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            error == null
                ? 'Status dicek otomatis. Halaman ini akan berpindah sendiri '
                      'setelah pembayaran diterima.'
                : '$error Pengecekan dicoba lagi otomatis.',
            style: TextStyle(
              color: error == null ? palette.textMuted : palette.dangerText,
              fontSize: AppTextSizes.small,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentDetails(BuildContext context, PaymentInfo payment) {
    final palette = context.palette;

    if (payment.hasQr) {
      return GlassCard(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: (payment.qrString ?? '').isNotEmpty
                  ? QrImageView(
                      data: payment.qrString!,
                      size: 220,
                      backgroundColor: Colors.white,
                    )
                  : Image.network(
                      payment.qrUrl!,
                      width: 220,
                      height: 220,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 220,
                        height: 220,
                        child: Center(
                          child: Text(
                            'Kode QR tidak dapat dimuat.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              payment.type == 'ewallet'
                  ? 'Scan kode QR ini dengan aplikasi ${_providerName(payment.provider) ?? 'e-wallet'}.'
                  : 'Scan kode QR ini dengan aplikasi mobile banking atau '
                        'e-wallet apa pun yang mendukung QRIS.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted, height: 1.4),
            ),
          ],
        ),
      );
    }

    final rows = <(String, String)>[
      if (payment.vaNumber != null)
        ('Nomor Virtual Account', payment.vaNumber!),
      if (payment.billerCode != null) ('Kode Perusahaan', payment.billerCode!),
      if (payment.billKey != null) ('Kode Pembayaran', payment.billKey!),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Virtual Account ${payment.provider?.toUpperCase() ?? ''}'.trim(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: AppTextSizes.bodyLarge,
              color: palette.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (label, value) in rows) ...[
            Text(
              label,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: AppTextSizes.small,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: palette.text,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Salin $label',
                  onPressed: () => _copy(label, value),
                  icon: const Icon(Icons.copy_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (rows.isEmpty)
            Text(
              'Data pembayaran tidak tersedia.',
              style: TextStyle(color: palette.textMuted),
            ),
          Text(
            'Bayar lewat ATM, mobile banking, atau internet banking dengan '
            'memilih menu Virtual Account / Bayar.',
            style: TextStyle(color: palette.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
