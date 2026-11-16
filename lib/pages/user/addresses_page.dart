import 'package:flutter/material.dart';
import 'package:motopart/models/shipping_address.dart';
import 'package:motopart/pages/user/address_form_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

/// Daftar alamat pengiriman tersimpan: tambah, ubah, hapus, dan pilih utama.
class AddressesPage extends StatelessWidget {
  const AddressesPage({super.key});

  Future<void> _add(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AddressFormPage()),
  );

  Future<void> _edit(BuildContext context, ShippingAddress address) =>
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddressFormPage(address: address)),
      );

  Future<void> _delete(BuildContext context, ShippingAddress address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Hapus alamat?'),
        content: Text('Alamat "${address.label}" akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) auth.deleteAddress(address.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alamat Pengiriman')),
      body: AnimatedBuilder(
        animation: auth,
        builder: (context, _) {
          final account = auth.currentAccount;
          final addresses = account?.addresses ?? const <ShippingAddress>[];
          final defaultId = account?.defaultAddress?.id;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  if (addresses.isEmpty)
                    const _EmptyAddresses()
                  else
                    for (final a in addresses) ...[
                      _AddressCard(
                        address: a,
                        isDefault: a.id == defaultId,
                        onEdit: () => _edit(context, a),
                        onDelete: () => _delete(context, a),
                        onMakeDefault: () => auth.setDefaultAddress(a.id),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    text: 'Tambah Alamat Baru',
                    icon: Icons.add_location_alt_rounded,
                    onPressed: () => _add(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyAddresses extends StatelessWidget {
  const _EmptyAddresses();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.location_off_outlined, size: 56, color: palette.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Belum ada alamat tersimpan',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: AppTextSizes.bodyLarge,
              color: palette.text,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tambahkan alamat agar checkout lebih cepat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final ShippingAddress address;
  final bool isDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMakeDefault;

  const _AddressCard({
    required this.address,
    required this.isDefault,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final compact = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 20,
                color: palette.primaryText,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  address.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: AppTextSizes.bodyLarge,
                    color: palette.text,
                  ),
                ),
              ),
              if (isDefault) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Utama',
                    style: TextStyle(
                      fontSize: AppTextSizes.small,
                      fontWeight: FontWeight.w700,
                      color: palette.primaryText,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${address.recipient} · ${address.phone}',
            style: TextStyle(fontWeight: FontWeight.w600, color: palette.text),
          ),
          const SizedBox(height: 2),
          Text(address.fullText, style: TextStyle(color: palette.textMuted)),
          if (address.hasLocation) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.gps_fixed_rounded,
                  size: 14,
                  color: palette.primaryText,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'GPS: ${address.coordinatesText}',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AppTextSizes.small,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (address.note.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Patokan: ${address.note}',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: AppTextSizes.small,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                style: compact,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Ubah'),
              ),
              if (!isDefault)
                TextButton.icon(
                  onPressed: onMakeDefault,
                  style: compact,
                  icon: const Icon(Icons.star_outline_rounded, size: 18),
                  label: const Text('Jadikan Utama'),
                ),
              TextButton.icon(
                onPressed: onDelete,
                style: compact.copyWith(
                  foregroundColor: WidgetStatePropertyAll(palette.dangerText),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Hapus'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
