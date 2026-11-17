import 'package:flutter/material.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/primary_button.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String text;

  const _Slide(this.icon, this.title, this.text);
}

const _slides = [
  _Slide(
    Icons.inventory_2_rounded,
    'Lengkap & Berkualitas',
    'Temukan ribuan sparepart motor dengan tampilan modern dan pengalaman belanja yang nyaman.',
  ),
  _Slide(
    Icons.two_wheeler_rounded,
    'Cocok untuk Motormu',
    'Cari berdasarkan kategori dan tipe motor, lalu bandingkan harga dengan mudah.',
  ),
  _Slide(
    Icons.local_shipping_rounded,
    'Belanja Praktis',
    'Checkout cepat, pilih kurir, dan pantau status pesananmu dari satu tempat.',
  ),
];

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final controller = PageController();
  int page = 0;

  bool get isLast => page == _slides.length - 1;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _toLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _next() {
    if (isLast) {
      _toLogin();
    } else {
      controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isLast ? 0 : 1,
                      child: TextButton(
                        onPressed: isLast ? null : _toLogin,
                        child: const Text('Lewati'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: controller,
                      itemCount: _slides.length,
                      onPageChanged: (value) => setState(() => page = value),
                      itemBuilder: (context, index) =>
                          _SlideView(slide: _slides[index]),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          key: ValueKey('onboarding-dot-$i'),
                          duration: const Duration(milliseconds: 220),
                          width: i == page ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: i == page
                                ? context.palette.accent
                                : palette.textMuted.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    text: isLast ? 'Mulai Sekarang' : 'Lanjut',
                    icon: isLast
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 360),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.palette.accent.withValues(alpha: 0.28),
                    palette.surfaceAlt,
                  ],
                ),
              ),
              child: Icon(slide.icon, size: 108, color: palette.primaryText),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontSize: AppTextSizes.display),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              slide.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
