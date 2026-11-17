import 'package:flutter/material.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

/// Ganti password akun yang sedang login (pembeli maupun admin).
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final oldPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    oldPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  bool busy = false;

  Future<void> submit() async {
    if (busy) return;
    String? error;
    if (oldPassword.text.isEmpty ||
        newPassword.text.isEmpty ||
        confirmPassword.text.isEmpty) {
      error = 'Lengkapi semua kolom terlebih dahulu.';
    } else if (newPassword.text != confirmPassword.text) {
      error = 'Konfirmasi password tidak sama.';
    } else {
      busy = true;
      try {
        error = await auth.changePasswordAsync(
          oldPassword: oldPassword.text,
          newPassword: newPassword.text,
        );
      } finally {
        busy = false;
      }
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Password berhasil diubah.')),
    );
    Navigator.pop(context);
  }

  Widget _field(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Tampilkan password' : 'Sembunyikan password',
          onPressed: () => setState(() => obscure = !obscure),
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: palette.primaryText,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Gunakan password yang sulit ditebak dan berbeda dari '
                      'password lamamu.',
                      style: TextStyle(color: palette.textMuted, height: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              GlassCard(
                child: Column(
                  children: [
                    _field('Password lama', oldPassword),
                    const SizedBox(height: AppSpacing.lg),
                    _field(
                      'Password baru (minimal ${AuthStore.minPasswordLength} karakter)',
                      newPassword,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _field('Ulangi password baru', confirmPassword),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                text: 'Simpan Password',
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
