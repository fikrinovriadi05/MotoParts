import 'package:flutter/material.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/selectable_card.dart';

/// Pilihan metode pembayaran: kartu per kelompok (Transfer Bank, E-Wallet,
/// Virtual Account, COD). Pilihan bank/dompet muncul tepat di bawah kartu
/// yang dipilih.
class PaymentMethodPicker extends StatelessWidget {
  final PaymentChoice value;
  final ValueChanged<PaymentChoice> onChanged;

  const PaymentMethodPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value.group;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in PaymentMethods.available) ...[
          SelectableCard(
            selected: selected.name == group.name,
            onTap: () {
              if (selected.name != group.name) {
                onChanged(PaymentMethods.firstOf(group));
              }
            },
            icon: group.icon,
            title: group.name,
            subtitle: group.description,
          ),
          if (selected.name == group.name && group.hasProviders)
            _Providers(
              group: group,
              provider: value.provider,
              onSelected: (p) => onChanged(PaymentChoice(group, p)),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _Providers extends StatelessWidget {
  final PaymentGroup group;
  final String? provider;
  final ValueChanged<String> onSelected;

  const _Providers({
    required this.group,
    required this.provider,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.providerLabel,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: palette.text,
              fontSize: AppTextSizes.body,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final p in group.providers)
                ChoiceChip(
                  label: Text(p),
                  selected: provider == p,
                  onSelected: (_) => onSelected(p),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
