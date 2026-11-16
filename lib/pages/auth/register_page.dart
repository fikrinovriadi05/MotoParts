import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/store/auth_store.dart';
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

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  void submit() {
    final error = auth.register(
      name: name.text,
      email: email.text,
      phone: phone.text,
      password: password.text,
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            'Buat Akun Baru',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: context.palette.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lengkapi data berikut untuk mulai berbelanja di MotoPart.',
            style: TextStyle(color: context.palette.textMuted),
          ),
          const SizedBox(height: 24),
          _field('Nama Lengkap', name, Icons.person_outline_rounded),
          _field('Email', email, Icons.email_outlined),
          _field('No. HP', phone, Icons.phone_outlined),
          _field(
            'Password (minimal ${AuthStore.minPasswordLength} karakter)',
            password,
            Icons.lock_outline_rounded,
            obscure: true,
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            text: 'Daftar',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: submit,
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}
