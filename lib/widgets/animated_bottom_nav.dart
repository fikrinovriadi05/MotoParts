import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

/// Satu menu di [AnimatedBottomNav].
class BottomNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Membuat widget ikon (mis. dengan badge). Bawaan: `Icon(icon)`.
  final Widget Function(IconData icon)? iconBuilder;

  const BottomNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.iconBuilder,
  });
}

/// Navigasi bawah dengan indikator lingkaran melayang berwarna aksen yang
/// bergeser halus ke menu terpilih. Ikon aktif membesar dan terangkat ke
/// dalam lingkaran; ikon lain abu-abu. Label tetap tampil di bawah ikon.
///
/// Tinggi tetap ([totalHeight] + area aman bawah); latar mengikuti tema
/// (putih di mode terang) dan melebar penuh, sedangkan menunya dibatasi
/// [maxContentWidth] di layar lebar.
class AnimatedBottomNav extends StatelessWidget {
  /// Tinggi bilah (tanpa area aman bawah dan tanpa pita lingkaran melayang).
  static const barHeight = 68.0;

  /// Pita di atas bilah tempat lingkaran melayang menonjol.
  static const floatBand = 14.0;

  static const indicatorSize = 52.0;

  /// Jarak label dari dasar bilah.
  static const labelBottom = 6.0;
  static const totalHeight = floatBand + barHeight;

  /// Lebar maksimum area menu (agar tidak terlalu renggang di layar lebar).
  static const maxContentWidth = 520.0;

  static const moveDuration = Duration(milliseconds: 420);

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<BottomNavItem> items;

  const AnimatedBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  /// Posisi kiri lingkaran untuk menu ke-[index] dengan lebar area [width].
  static double indicatorLeft(int index, double width, int count) {
    final slot = width / count;
    return slot * index + (slot - indicatorSize) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final duration = UiConfig.motion(moveDuration);

    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: totalHeight + bottom,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Latar bilah: putih sedikit transparan (mengikuti tema) dengan
            // sudut atas membulat dan bayangan halus.
            Positioned(
              left: 0,
              right: 0,
              top: floatBand,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.96),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                  border: Border(top: BorderSide(color: palette.border)),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow,
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: maxContentWidth,
                    ),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final slot = box.maxWidth / items.length;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Lingkaran penanda menu aktif.
                            AnimatedPositioned(
                              key: const ValueKey('nav-indicator'),
                              duration: duration,
                              curve: Curves.easeOutBack,
                              left: indicatorLeft(
                                selectedIndex,
                                box.maxWidth,
                                items.length,
                              ),
                              top: 8,
                              width: indicatorSize,
                              height: indicatorSize,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      palette.accentSoft,
                                      palette.accent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette.accent.withValues(
                                        alpha: 0.45,
                                      ),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            for (var i = 0; i < items.length; i++)
                              Positioned(
                                left: slot * i,
                                width: slot,
                                top: 0,
                                bottom: 0,
                                child: _NavButton(
                                  item: items[i],
                                  selected: i == selectedIndex,
                                  duration: duration,
                                  onTap: () => onSelected(i),
                                ),
                              ),
                          ],
                        );
                      },
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
}

class _NavButton extends StatelessWidget {
  final BottomNavItem item;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final iconData = selected ? item.activeIcon : item.icon;
    final icon = item.iconBuilder?.call(iconData) ?? Icon(iconData);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightShape: BoxShape.circle,
        splashColor: palette.accent.withValues(alpha: 0.18),
        highlightColor: Colors.transparent,
        hoverColor: palette.accent.withValues(alpha: 0.06),
        child: Stack(
          children: [
            // Ikon: aktif membesar dan terangkat ke tengah lingkaran.
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: AnimatedSlide(
                  offset: Offset(0, selected ? -0.25 : 0),
                  duration: duration,
                  curve: Curves.easeOutBack,
                  child: AnimatedScale(
                    scale: selected ? 1.18 : 1,
                    duration: duration,
                    curve: Curves.easeOutBack,
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: selected ? palette.onAccent : palette.textMuted,
                      ),
                      duration: duration,
                      builder: (context, color, child) => IconTheme(
                        data: IconThemeData(color: color, size: 24),
                        child: child!,
                      ),
                      child: icon,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: AnimatedBottomNav.labelBottom,
              child: AnimatedDefaultTextStyle(
                duration: duration,
                style: TextStyle(
                  fontSize: AppTextSizes.caption,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? palette.primaryText : palette.textMuted,
                ),
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
