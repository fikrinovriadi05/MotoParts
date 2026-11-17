import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:motopart/pages/admin/admin_shell.dart';
import 'package:motopart/pages/auth/onboarding_page.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/widgets/brand_mark.dart';

/// Layar pembuka. Penyimpanan, sesi login, dan data sudah dimuat di `main()`
/// sebelum aplikasi tampil, jadi splash tidak menunggu durasi tetap: begitu
/// animasi pembuka selesai, pengguna langsung diarahkan ke halaman tujuan.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const Color _charcoal = Color(0xFF202124);
  static const Color _orange = Color(0xFFFF6B00);

  late final AnimationController _intro;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _motoReveal;
  late final Animation<double> _partReveal;
  late final Animation<double> _taglineReveal;
  late final Animation<double> _loaderReveal;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    Animation<double> interval(double begin, double end, Curve curve) =>
        CurvedAnimation(
          parent: _intro,
          curve: Interval(begin, end, curve: curve),
        );

    _logoFade = interval(0.0, 0.40, Curves.easeOut);
    _logoScale = Tween<double>(
      begin: 0.82,
      end: 1,
    ).animate(interval(0.0, 0.50, Curves.easeOutCubic));
    _motoReveal = interval(0.25, 0.60, Curves.easeOutCubic);
    _partReveal = interval(0.35, 0.70, Curves.easeOutCubic);
    _taglineReveal = interval(0.55, 0.90, Curves.easeOut);
    _loaderReveal = interval(0.60, 0.85, Curves.easeOut);

    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
    _intro.forward();
  }

  void _finish() {
    if (!mounted) return;
    // Inisialisasi selesai: hentikan indikator, lalu pindah halaman.
    setState(() => _loading = false);
    // Sesi login yang tersimpan: langsung ke beranda sesuai perannya.
    final Widget next = !auth.isLoggedIn
        ? const OnboardingPage()
        : auth.isAdmin
        ? const AdminShell()
        : const UserShell();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = math.min(size.width, size.height);
    // Ukuran proporsional terhadap layar, dengan batas agar tetap nyaman.
    final logoSize = (shortest * 0.38).clamp(110.0, 170.0);
    final titleSize = (shortest * 0.115).clamp(34.0, 52.0);

    return Scaffold(
      backgroundColor: _charcoal,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_charcoal, _charcoal, Color(0xFF4A2A14), _orange],
            stops: [0.0, 0.50, 0.80, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -size.width * 0.28,
              right: -size.width * 0.30,
              child: _Circle(diameter: size.width * 0.85, alpha: 0.06),
            ),
            Positioned(
              bottom: -size.width * 0.40,
              left: -size.width * 0.35,
              child: _Circle(diameter: size.width * 1.0, alpha: 0.10),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeTransition(
                          opacity: _logoFade,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: BrandMark(size: logoSize),
                          ),
                        ),
                        SizedBox(height: logoSize * 0.16),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Reveal(
                                animation: _motoReveal,
                                child: Text(
                                  'Moto',
                                  style: _titleStyle(titleSize, Colors.white),
                                ),
                              ),
                              _Reveal(
                                animation: _partReveal,
                                child: Text(
                                  'Part',
                                  style: _titleStyle(titleSize, _orange),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        FadeTransition(
                          opacity: _taglineReveal,
                          child: Text(
                            'Sparepart Motor Lengkap, Cepat, Modern, dan Terpercaya.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 14.5,
                              height: 1.55,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: FadeTransition(
                            opacity: _loaderReveal,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _loading ? 1 : 0,
                              child: _loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.4,
                                      strokeCap: StrokeCap.round,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _titleStyle(double fontSize, Color color) => TextStyle(
    color: color,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    letterSpacing: -1,
    height: 1.1,
  );
}

/// Muncul bertahap: memudar sambil naik sedikit dari bawah.
class _Reveal extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _Reveal({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double diameter;
  final double alpha;

  const _Circle({required this.diameter, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
