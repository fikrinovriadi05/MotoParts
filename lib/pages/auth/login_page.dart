import 'package:flutter/material.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/pages/admin/admin_shell.dart';
import 'package:motopart/pages/auth/register_page.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/auth_scaffold.dart';
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
                    'lewat Akun > Ganti Password.',
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

    userTabIndex.value = UserTab.home;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => admin ? const AdminShell() : const UserShell(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Selamat Datang',
      subtitle: admin
          ? 'Masuk sebagai admin untuk mengelola toko.'
          : 'Masuk untuk mulai belanja sparepart favoritmu.',
      children: [
        _RoleTabs(admin: admin, onChanged: (v) => setState(() => admin = v)),
        const SizedBox(height: AppSpacing.xl),
        const FieldLabel('Email'),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'user@email.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const FieldLabel('Password'),
        TextField(
          controller: password,
          obscureText: obscure,
          onSubmitted: (_) => login(),
          decoration: InputDecoration(
            hintText: 'Masukkan password',
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
          text: 'Masuk',
          icon: Icons.login_rounded,
          onPressed: login,
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: TextButton(
            onPressed: _showForgotPassword,
            child: const Text('Lupa password?'),
          ),
        ),
        if (!admin)
          Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterPage()),
              ),
              child: const Text('Belum punya akun? Daftar'),
            ),
          ),
      ],
    );
  }
}

/// Pilihan masuk sebagai pembeli (User) atau Admin.
class _RoleTabs extends StatelessWidget {
  final bool admin;
  final ValueChanged<bool> onChanged;

  const _RoleTabs({required this.admin, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget tab(String label, IconData icon, bool value) {
      final selected = admin == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: 'Masuk sebagai $label',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: AppSizes.minTap,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? AppColors.onPrimary : palette.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? AppColors.onPrimary : palette.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          tab('User', Icons.person_rounded, false),
          tab('Admin', Icons.admin_panel_settings_rounded, true),
        ],
      ),
    );
  }
}
