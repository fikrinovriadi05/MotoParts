import 'package:flutter/material.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

/// Ubah nama dan nomor telepon. Email tidak bisa diubah.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final name = TextEditingController(text: auth.currentAccount?.name ?? '');
  final phone = TextEditingController(text: auth.currentAccount?.phone ?? '');
  final motorName = TextEditingController(
    text: auth.currentAccount?.motorName ?? '',
  );
  final motorType = TextEditingController(
    text: auth.currentAccount?.motorType ?? '',
  );
  final motorYear = TextEditingController(
    text: auth.currentAccount?.motorYear?.toString() ?? '',
  );

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    motorName.dispose();
    motorType.dispose();
    motorYear.dispose();
    super.dispose();
  }

  void submit() {
    final error = auth.updateProfile(
      name: name.text,
      phone: phone.text,
      motorName: motorName.text,
      motorType: motorType.text,
      motorYear: motorYear.text,
    );
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Data akun berhasil disimpan.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final initial = (auth.currentAccount?.firstName ?? '?').characters.first
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Data Akun')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        context.palette.accentSoft,
                        context.palette.accent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.palette.accent.withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: context.palette.onAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              GlassCard(
                child: Column(
                  children: [
                    TextField(
                      controller: name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      enabled: false,
                      controller: TextEditingController(
                        text: auth.currentAccount?.email ?? '',
                      ),
                      style: TextStyle(color: palette.textMuted),
                      decoration: const InputDecoration(
                        labelText: 'Email (tidak dapat diubah)',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'No. HP',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.two_wheeler_rounded,
                          size: 20,
                          color: palette.primaryText,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Motor Saya',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppTextSizes.bodyLarge,
                              fontWeight: FontWeight.w800,
                              color: palette.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Opsional. Membantu memilih sparepart yang cocok.',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: AppTextSizes.small,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: motorName,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama Motor',
                        hintText: 'mis. Honda Beat',
                        prefixIcon: Icon(Icons.two_wheeler_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: motorType,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Tipe Motor',
                        hintText: 'mis. Street, CBS, 125 eSP',
                        prefixIcon: Icon(Icons.tune_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: motorYear,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Tahun',
                        hintText: 'mis. 2020',
                        counterText: '',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                text: 'Simpan',
                icon: Icons.check_rounded,
                onPressed: submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
