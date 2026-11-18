import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motopart/core/google_sign_in_service.dart';
import 'package:motopart/core/navigation.dart';
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
  bool obscure = true;
  bool googleBusy = false;
  StreamSubscription<GoogleProfile>? _googleEvents;
  late final Future<Widget?> _googleWebButton = googleSignInService.webButton();

  @override
  void initState() {
    super.initState();
    // Web: tombol resmi Google mengirim hasil masuk lewat aliran ini.
    _googleEvents = googleSignInService.profiles.listen(_finishGoogle);
  }

  @override
  void dispose() {
    _googleEvents?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lupa Password'),
        content: const Text(
          'Pembeli: hubungi admin toko untuk mengatur ulang password. Admin '
          'akan memberi password sementara yang bisa diganti lewat '
          'Akun > Ganti Password.\n\n'
          'Admin: password diubah lewat menu Ganti Password setelah masuk. '
          'Jika terlupa, hapus data aplikasi untuk mengembalikan akun admin '
          'ke pengaturan awal.\n\n'
          'Atau masuk dengan akun Google.',
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

  bool busy = false;

  Future<void> login() async {
    if (busy) return;
    busy = true;
    final String? error;
    try {
      error = await auth.loginAsync(email: email.text, password: password.text);
    } finally {
      busy = false;
    }
    _afterLogin(error);
  }

  /// Menampilkan kesalahan, atau membuka halaman sesuai peran akun (pembeli
  /// atau admin) setelah masuk.
  void _afterLogin(String? error) {
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    userTabIndex.value = UserTab.home;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => auth.isAdmin ? const AdminShell() : const UserShell(),
      ),
    );
  }

  /// Tombol Google sendiri (mobile/desktop): pemilih akun Google.
  Future<void> loginWithGoogle() async {
    if (googleBusy) return;
    if (!googleSignInService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Masuk dengan Google belum diatur. Jalankan aplikasi dengan '
            'GOOGLE_CLIENT_ID (lihat README).',
          ),
        ),
      );
      return;
    }
    setState(() => googleBusy = true);
    try {
      final profile = await googleSignInService.signIn();
      if (profile == null) return; // dibatalkan pengguna
      await _finishGoogle(profile);
    } on GoogleSignInFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => googleBusy = false);
    }
  }

  Future<void> _finishGoogle(GoogleProfile profile) async {
    _afterLogin(await auth.loginWithGoogleAsync(profile));
  }

  /// Web (sudah diatur): tombol resmi Google. Lainnya: tombol sendiri.
  Widget _googleButton() {
    return FutureBuilder<Widget?>(
      future: _googleWebButton,
      builder: (context, snapshot) {
        final web = snapshot.data;
        if (web != null) return Center(child: web);
        return OutlinedButton.icon(
          key: const ValueKey('google-login'),
          onPressed: googleBusy ? null : loginWithGoogle,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          ),
          icon: googleBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const _GoogleMark(),
          label: const Text('Lanjutkan dengan Google'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Selamat Datang',
      subtitle: 'Masuk untuk mulai belanja sparepart favoritmu.',
      children: [
        const FieldLabel('Email'),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'nama@email.com',
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
        const SizedBox(height: AppSpacing.lg),
        const _OrDivider(),
        const SizedBox(height: AppSpacing.lg),
        _googleButton(),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: TextButton(
            onPressed: _showForgotPassword,
            child: const Text('Lupa password?'),
          ),
        ),
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

/// Pemisah "atau" antara masuk dengan password dan dengan Google.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(child: Divider(color: palette.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('atau', style: TextStyle(color: palette.textMuted)),
        ),
        Expanded(child: Divider(color: palette.border)),
      ],
    );
  }
}

/// Huruf "G" berwarna Google sebagai penanda tombol.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontWeight: FontWeight.w900,
        fontSize: 20,
        height: 1,
      ),
    );
  }
}
