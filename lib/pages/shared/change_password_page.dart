import 'package:flutter/material.dart';
import 'package:motopart/store/auth_store.dart';
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

  void submit() {
    String? error;
    if (oldPassword.text.isEmpty ||
        newPassword.text.isEmpty ||
        confirmPassword.text.isEmpty) {
      error = 'Lengkapi semua kolom terlebih dahulu.';
    } else if (newPassword.text != confirmPassword.text) {
      error = 'Konfirmasi password tidak sama.';
    } else {
      error = auth.changePassword(
        oldPassword: oldPassword.text,
        newPassword: newPassword.text,
      );
    }

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Password')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          _field('Password lama', oldPassword),
          _field(
            'Password baru (minimal ${AuthStore.minPasswordLength} karakter)',
            newPassword,
          ),
          _field('Ulangi password baru', confirmPassword),
          const SizedBox(height: 8),
          PrimaryButton(
            text: 'Simpan Password',
            icon: Icons.check_rounded,
            onPressed: submit,
          ),
        ],
      ),
    );
  }
}
