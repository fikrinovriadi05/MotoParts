import 'package:flutter/material.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/payment_method_picker.dart';
import 'package:motopart/widgets/primary_button.dart';

/// Memilih metode pembayaran favorit. Metode ini terpilih otomatis saat
/// membayar pesanan (masih bisa diganti di halaman pembayaran).
class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  late PaymentChoice choice =
      PaymentMethods.decode(auth.currentAccount?.preferredPayment) ??
      PaymentMethods.defaultChoice;

  void save() {
    final error = auth.setPreferredPayment(choice.encoded);
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('${choice.label} disimpan sebagai favorit.')),
    );
    Navigator.pop(context);
  }

  void clear() {
    auth.setPreferredPayment(null);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Metode favorit dihapus.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasSaved =
        PaymentMethods.decode(auth.currentAccount?.preferredPayment) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Metode Pembayaran')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(
                'Pilih metode favorit. Metode ini akan terpilih otomatis saat '
                'Anda membayar pesanan.',
                style: TextStyle(color: palette.textMuted, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.lg),
              PaymentMethodPicker(
                value: choice,
                onChanged: (c) => setState(() => choice = c),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                text: 'Simpan sebagai Favorit',
                icon: Icons.check_rounded,
                onPressed: save,
              ),
              if (hasSaved) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: clear,
                  child: const Text('Hapus metode favorit'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
