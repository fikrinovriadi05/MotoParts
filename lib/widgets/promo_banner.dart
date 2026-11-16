import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

class PromoSlide {
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;

  /// Kategori yang dibuka saat banner ditekan (null = katalog semua produk).
  final String? category;

  const PromoSlide({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.category,
  });
}

const defaultPromoSlides = [
  PromoSlide(
    label: 'PROMO SPESIAL',
    title: 'Diskon\nhingga 30%',
    subtitle: 'Sparepart pilihan dengan harga lebih hemat.',
    icon: Icons.local_offer_rounded,
  ),
  PromoSlide(
    label: 'SERVIS RUTIN',
    title: 'Oli & filter\nsiap pakai',
    subtitle: 'Jaga mesin tetap halus di setiap perjalanan.',
    icon: Icons.oil_barrel_rounded,
    category: 'Oli',
  ),
  PromoSlide(
    label: 'PENGEREMAN',
    title: 'Kampas rem\nlebih pakem',
    subtitle: 'Berkendara lebih aman, jarak henti lebih pendek.',
    icon: Icons.album_rounded,
    category: 'Rem',
  ),
];

/// Banner promo yang bisa digeser, dengan indikator titik.
class PromoBanner extends StatefulWidget {
  final List<PromoSlide> slides;
  final ValueChanged<PromoSlide>? onTapSlide;

  const PromoBanner({
    super.key,
    this.slides = defaultPromoSlides,
    this.onTapSlide,
  });

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  final controller = PageController(viewportFraction: 0.92);
  int page = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: controller,
            itemCount: widget.slides.length,
            onPageChanged: (value) => setState(() => page = value),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _Slide(
                  slide: widget.slides[index],
                  onTap: widget.onTapSlide == null
                      ? null
                      : () => widget.onTapSlide!(widget.slides[index]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.slides.length; i++)
              AnimatedContainer(
                key: ValueKey('promo-dot-$i'),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: i == page ? 22 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == page
                      ? AppColors.primary
                      : palette.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Slide extends StatelessWidget {
  final PromoSlide slide;
  final VoidCallback? onTap;

  const _Slide({required this.slide, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Teks banner dibatasi agar tidak meluap saat font sistem dibesarkan.
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: 1.1),
      ),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.charcoalSoft, AppColors.charcoal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg + 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slide.label,
                          style: const TextStyle(
                            color: AppColors.primarySoft,
                            fontWeight: FontWeight.w700,
                            fontSize: AppTextSizes.small,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          slide.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          slide.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: AppTextSizes.small,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(slide.icon, color: AppColors.primary, size: 38),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
