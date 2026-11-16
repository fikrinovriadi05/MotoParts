import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/pages/user/orders_page.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({super.key});

  void _goHome(BuildContext context) {
    userTabIndex.value = UserTab.home;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const UserShell()),
      (route) => false,
    );
  }

  void _viewOrders(BuildContext context) {
    userTabIndex.value = UserTab.account;
    final navigator = Navigator.of(context);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UserShell()),
      (route) => false,
    );
    navigator.push(MaterialPageRoute(builder: (_) => const OrdersPage()));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final orders = store.ordersForCurrentAccount;
    final order = orders.isEmpty ? null : orders.first;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl + 2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.withValues(alpha: 0.16),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.success,
                        size: 68,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Pembayaran Berhasil!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Pesanan kamu telah diterima dan sedang diproses.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textMuted, height: 1.6),
                  ),
                  if (order != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    GlassCard(
                      child: Column(
                        children: [
                          _row(context, 'Kode Pesanan', order.code),
                          const SizedBox(height: AppSpacing.sm),
                          _row(
                            context,
                            'Total',
                            formatRupiah(order.total),
                            highlight: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  PrimaryButton(
                    text: 'Lihat Pesanan',
                    icon: Icons.receipt_long_rounded,
                    onPressed: () => _viewOrders(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    text: 'Kembali ke Beranda',
                    outline: true,
                    onPressed: () => _goHome(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    final palette = context.palette;
    return Row(
      children: [
        Text(label, style: TextStyle(color: palette.textMuted)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: highlight ? palette.primaryText : palette.text,
            ),
          ),
        ),
      ],
    );
  }
}
