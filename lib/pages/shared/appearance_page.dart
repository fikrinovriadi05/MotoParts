import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/theme/app_accent.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/theme/theme_controller.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/hover.dart';
import 'package:motopart/widgets/motopart_wordmark.dart';

/// Pengaturan Tampilan: mode terang/gelap/sistem dan warna aksen, dengan
/// pratinjau yang langsung berubah. Dipakai pembeli (menu Akun) maupun admin.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Tampilan')),
      body: ListenableBuilder(
        listenable: themeController.changes,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              const _SectionCard(
                title: 'Mode',
                subtitle: 'Terang, gelap, atau ikuti pengaturan perangkat.',
                child: _ModePicker(),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SectionCard(
                title: 'Warna Aksen',
                subtitle: 'Dipakai untuk tombol, pilihan aktif, dan sorotan.',
                child: _AccentPicker(),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SectionCard(
                title: 'Pratinjau',
                subtitle: 'Contoh tampilan dengan pilihan Anda.',
                child: _PreviewCard(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: AppTextSizes.small,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => _segments(context),
    );
  }

  Widget _segments(BuildContext context) {
    final palette = context.palette;
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(AppSizes.minTap, AppSizes.minTap),
        selectedBackgroundColor: palette.accent.withValues(alpha: 0.2),
        selectedForegroundColor: palette.primaryText,
        foregroundColor: palette.textMuted,
        side: BorderSide(color: palette.border),
      ),
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Terang'),
          icon: Icon(Icons.light_mode_rounded),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Gelap'),
          icon: Icon(Icons.dark_mode_rounded),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('Sistem'),
          icon: Icon(Icons.smartphone_rounded),
        ),
      ],
      selected: {themeController.value},
      onSelectionChanged: (selection) =>
          themeController.setMode(selection.first),
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController.accent,
      builder: (context, _) => _dots(),
    );
  }

  Widget _dots() {
    final current = themeController.accent.value;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final accent in AppAccent.values)
          _AccentDot(
            accent: accent,
            selected: accent == current,
            onTap: () => themeController.setAccent(accent),
          ),
      ],
    );
  }
}

/// Lingkaran warna aksen; yang aktif diberi cincin dan tanda centang.
class _AccentDot extends StatelessWidget {
  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  const _AccentDot({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Warna ${accent.label}',
      excludeSemantics: true,
      child: Tooltip(
        message: accent.label,
        child: HoverBuilder(
          builder: (context, hovered) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              // Area sentuh minimal 48x48 (lingkaran 40 + jarak).
              width: 56,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: hovered && !selected ? 1.08 : 1,
                    duration: UiConfig.motion(
                      const Duration(milliseconds: 120),
                    ),
                    child: AnimatedContainer(
                      duration: UiConfig.motion(
                        const Duration(milliseconds: 180),
                      ),
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? accent.color : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accent.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.color.withValues(
                                alpha: selected ? 0.4 : 0.2,
                              ),
                              blurRadius: selected ? 10 : 4,
                            ),
                          ],
                        ),
                        child: selected
                            ? Icon(
                                Icons.check_rounded,
                                color: accent.onColor,
                                size: 22,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    accent.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: AppTextSizes.caption,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? palette.text : palette.textMuted,
                    ),
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

/// Mini tampilan toko yang memakai tema yang sedang aktif.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('appearance-preview'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Flexible(child: MotoPartWordmark(fontSize: 20)),
              const Spacer(),
              Icon(Icons.shopping_cart_outlined, color: palette.primaryText),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.disc_full_rounded,
                    color: palette.primaryText,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kampas Rem Depan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        formatRupiah(45000),
                        style: TextStyle(
                          color: palette.primaryText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Tambah')),
              OutlinedButton(onPressed: () {}, child: const Text('Detail')),
              const Chip(label: Text('Rem')),
              const Chip(label: Text('Oli')),
            ],
          ),
        ],
      ),
    );
  }
}
