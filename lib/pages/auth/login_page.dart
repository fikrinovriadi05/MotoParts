import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/pages/admin/admin_shell.dart';
import 'package:motopart/pages/auth/register_page.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/widgets/app_logo.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool admin = false;
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lupa Password'),
        content: Text(
          admin
              ? 'Password admin diubah lewat menu Ganti Password setelah masuk. '
                    'Jika password terlupa, hapus data aplikasi untuk mengembalikan '
                    'akun admin ke pengaturan awal.'
              : 'Hubungi admin toko untuk mengatur ulang password Anda. '
                    'Admin akan memberi password sementara yang bisa Anda ganti '
                    'lewat Profil > Ganti Password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  void login() {
    final error = auth.login(
      email: email.text,
      password: password.text,
      role: admin ? AccountRole.admin : AccountRole.user,
    );
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => admin ? const AdminShell() : const UserShell(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.black, AppColors.dark, AppColors.bg],
            stops: [0.0, 0.28, 0.28],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SizedBox(height: 18),
              const Center(child: AppLogo(light: true, size: 30)),
              const SizedBox(height: 28),
              GlassCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selamat Datang',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      admin
                          ? 'Masuk sebagai admin untuk mengelola toko.'
                          : 'Masuk untuk mulai belanja sparepart favoritmu.',
                      style: const TextStyle(
                        color: AppColors.grey,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => admin = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !admin
                                      ? AppColors.blue
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'User',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: !admin
                                        ? Colors.white
                                        : AppColors.black,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => admin = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: admin
                                      ? AppColors.black
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Admin',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: admin
                                        ? Colors.white
                                        : AppColors.black,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Email',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: email,
                      decoration: const InputDecoration(
                        hintText: 'user@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Password',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: password,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        hintText: 'Masukkan password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => obscure = !obscure);
                          },
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      text: 'Masuk',
                      icon: Icons.login,
                      onPressed: login,
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: _showForgotPassword,
                        child: const Text('Lupa password?'),
                      ),
                    ),
                    if (!admin)
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Belum punya akun? Daftar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
