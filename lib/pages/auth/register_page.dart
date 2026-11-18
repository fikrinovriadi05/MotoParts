import 'package:flutter/material.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/widgets/auth_scaffold.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/primary_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool obscure = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  bool busy = false;

  Future<void> submit() async {
    if (busy) return;
    busy = true;
    final String? error;
    try {
      error = await auth.registerAsync(
        name: name.text,
        email: email.text,
        phone: phone.text,
        password: password.text,
        confirmPassword: confirm.text,
      );
    } finally {
      busy = false;
    }
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pendaftaran berhasil. Silakan masuk.')),
    );

    Navigator.pop(context);
  }

  Widget _visibilityToggle(bool hidden, VoidCallback onTap) => IconButton(
    tooltip: hidden ? 'Tampilkan password' : 'Sembunyikan password',
    onPressed: onTap,
    icon: Icon(
      hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mismatch = confirm.text.isNotEmpty && confirm.text != password.text;

    return AuthScaffold(
      showBack: true,
      title: 'Buat Akun Baru',
      subtitle: 'Lengkapi data berikut untuk mulai berbelanja di MotoPart.',
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
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'No. HP',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: password,
          obscureText: obscure,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: _visibilityToggle(
              obscure,
              () => setState(() => obscure = !obscure),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _PasswordRules(password: password.text),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: confirm,
          obscureText: obscureConfirm,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => submit(),
          decoration: InputDecoration(
            labelText: 'Konfirmasi Password',
            prefixIcon: const Icon(Icons.lock_reset_rounded),
            errorText: mismatch ? 'Konfirmasi password tidak sama.' : null,
            suffixIcon: _visibilityToggle(
              obscureConfirm,
              () => setState(() => obscureConfirm = !obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          text: 'Daftar',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: submit,
        ),
      ],
    );
  }
}

/// Aturan password yang harus dipenuhi; tiap baris berubah centang hijau saat
/// aturannya terpenuhi.
class _PasswordRules extends StatelessWidget {
  final String password;

  const _PasswordRules({required this.password});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ok = dark ? AppColors.success : const Color(0xFF15803D);

    return Container(
      key: const ValueKey('password-rules'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password harus memenuhi:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: AppTextSizes.small,
              color: palette.text,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          for (final rule in AuthStore.passwordRules)
            _ruleRow(rule, rule.test(password), ok, palette),
        ],
      ),
    );
  }

  Widget _ruleRow(PasswordRule rule, bool met, Color ok, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: met ? ok : palette.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              rule.label,
              style: TextStyle(
                fontSize: AppTextSizes.small,
                color: met ? ok : palette.textMuted,
                fontWeight: met ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
