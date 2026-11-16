import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/app.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rasio kontras WCAG antara dua warna.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('palet warna', () {
    test('dasar gelap memakai charcoal #1A1A1D dan aksen oranye #FF6B00', () {
      expect(AppPalette.dark.bg, const Color(0xFF1A1A1D));
      expect(AppColors.primary, const Color(0xFFFF6B00));
    });

    for (final entry in {
      'gelap': AppPalette.dark,
      'terang': AppPalette.light,
    }.entries) {
      final p = entry.value;

      test('kontras teks memadai di mode ${entry.key}', () {
        expect(contrast(p.text, p.bg), greaterThanOrEqualTo(7));
        expect(contrast(p.text, p.surface), greaterThanOrEqualTo(7));
        expect(contrast(p.textMuted, p.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.textMuted, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.primaryText, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.primaryText, p.bg), greaterThanOrEqualTo(4.5));
      });
    }

    test('teks di atas tombol oranye terbaca', () {
      expect(
        contrast(AppColors.onPrimary, AppColors.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('lerp antar palet menghasilkan warna di antaranya', () {
      final mid = AppPalette.light.lerp(AppPalette.dark, 0.5);

      expect(mid.bg, Color.lerp(AppPalette.light.bg, AppPalette.dark.bg, 0.5));
    });
  });

  group('ThemeData', () {
    test('tema terang dan gelap membawa palet masing-masing', () {
      expect(AppTheme.light().extension<AppPalette>(), AppPalette.light);
      expect(AppTheme.dark().extension<AppPalette>(), AppPalette.dark);
      expect(AppTheme.dark().scaffoldBackgroundColor, AppPalette.dark.bg);
      expect(AppTheme.light().scaffoldBackgroundColor, AppPalette.light.bg);
    });

    test('Material 3, kartu dan input berradius 16', () {
      final theme = AppTheme.dark();
      final card = theme.cardTheme.shape as RoundedRectangleBorder;

      expect(theme.useMaterial3, isTrue);
      expect(card.borderRadius, BorderRadius.circular(AppRadius.lg));
      expect(AppRadius.lg, 16);
    });

    test('area sentuh tombol minimal 48x48', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        for (final style in [
          theme.filledButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.textButtonTheme.style,
          theme.iconButtonTheme.style,
        ]) {
          final size = style!.minimumSize!.resolve({})!;
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
      }
    });

    testWidgets('context.palette membaca palet dari tema', (tester) async {
      late AppPalette seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              seen = context.palette;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(seen, AppPalette.dark);
    });

    testWidgets('tanpa tema MotoPart, palet bawaan mengikuti kecerahan', (
      tester,
    ) async {
      late AppPalette seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              seen = context.palette;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(seen, AppPalette.dark);
    });
  });

  group('ThemeController', () {
    test('awalnya mengikuti sistem', () {
      expect(ThemeController().value, ThemeMode.system);
    });

    test('pilihan tersimpan dan dimuat kembali', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = ThemeController();
      await first.attach(prefs);

      first.setMode(ThemeMode.dark);

      final reloaded = ThemeController();
      await reloaded.attach(prefs);
      expect(reloaded.value, ThemeMode.dark);
    });

    test('nilai tersimpan yang rusak diabaikan', () async {
      SharedPreferences.setMockInitialValues({
        ThemeController.storageKey: 'ungu',
      });
      final c = ThemeController();

      await c.attach(await SharedPreferences.getInstance());

      expect(c.value, ThemeMode.system);
    });
  });

  group('MotoPartApp', () {
    tearDown(() => themeController.setMode(ThemeMode.system));

    testWidgets('mengikuti pilihan mode gelap/terang', (tester) async {
      themeController.setMode(ThemeMode.dark);
      await tester.pumpWidget(const MotoPartApp());
      await tester.pump(const Duration(seconds: 2)); // lewati splash
      await tester.pumpAndSettle();

      var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);

      themeController.setMode(ThemeMode.light);
      await tester.pumpAndSettle();

      app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
    });
  });
}
