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
  bool obscure = true;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
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

  @override
  Widget build(BuildContext context) {
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
          onSubmitted: (_) => submit(),
          decoration: InputDecoration(
            labelText:
                'Password (minimal ${AuthStore.minPasswordLength} karakter)',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: obscure ? 'Tampilkan password' : 'Sembunyikan password',
              onPressed: () => setState(() => obscure = !obscure),
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
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
