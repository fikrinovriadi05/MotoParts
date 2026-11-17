import 'package:flutter/material.dart';
import 'package:motopart/core/app_info.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/brand_mark.dart';
import 'package:motopart/widgets/glass_card.dart';

/// Tentang MotoPart: kelompok pengembang dan anggotanya.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang MotoPart')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              const SizedBox(height: AppSpacing.md),
              const Center(child: BrandMark(size: 96)),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: palette.text,
                    ),
                    children: const [
                      TextSpan(text: 'Moto'),
                      TextSpan(
                        text: 'Part',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: Text(
                  'Versi ${AppInfo.version}',
                  style: TextStyle(color: palette.textMuted),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          size: 22,
                          color: palette.primaryText,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            AppInfo.groupName,
                            style: TextStyle(
                              fontSize: AppTextSizes.bodyLarge,
                              fontWeight: FontWeight.w800,
                              color: palette.text,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Anggota:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final (index, member) in AppInfo.members.indexed) ...[
                      _MemberRow(number: index + 1, member: member),
                      if (index != AppInfo.members.length - 1)
                        const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: AppInfo.name,
                  applicationVersion: AppInfo.version,
                ),
                icon: const Icon(Icons.description_outlined, size: 20),
                label: const Text('Lisensi sumber terbuka'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final int number;
  final TeamMember member;

  const _MemberRow({required this.number, required this.member});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.16),
          ),
          child: Text(
            '$number',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: palette.primaryText,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              Text(
                member.nim,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: AppTextSizes.small,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
