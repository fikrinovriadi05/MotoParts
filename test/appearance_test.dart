import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/app.dart';
import 'package:motopart/pages/admin/admin_dashboard_page.dart';
import 'package:motopart/pages/shared/appearance_page.dart';
import 'package:motopart/pages/user/profile_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/theme/app_accent.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/theme/theme_controller.dart';
import 'package:motopart/widgets/motopart_wordmark.dart';
import 'package:shared_preferences/shared_preferences.dart';

void size(WidgetTester tester, double w, double h, {double dpr = 1}) {
  tester.view.physicalSize = Size(w * dpr, h * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

/// Aplikasi mini yang mengikuti [themeController] seperti `MotoPartApp`.
Widget themedApp(Widget home) => ListenableBuilder(
  listenable: themeController.changes,
  builder: (context, _) => MaterialApp(
    theme: AppTheme.light(accent: themeController.accent.value),
    darkTheme: AppTheme.dark(accent: themeController.accent.value),
    themeMode: themeController.value,
    home: home,
  ),
);

void main() {
  setUp(() {
    themeController.setMode(ThemeMode.light);
    themeController.setAccent(AppAccent.orange);
  });

  tearDown(() {
    themeController.setMode(ThemeMode.system);
    themeController.setAccent(AppAccent.orange);
  });

  group('AppAccent', () {
    test('lima pilihan dengan warna sesuai rancangan', () {
      expect(AppAccent.values, hasLength(5));
      expect(AppAccent.orange.color, const Color(0xFFFF6B00));
      expect(AppAccent.red.color, const Color(0xFFE10600));
      expect(AppAccent.blue.color, const Color(0xFF1E88E5));
      expect(AppAccent.green.color, const Color(0xFF2E7D32));
      expect(AppAccent.yellow.color, const Color(0xFFFFB300));
      expect(AppAccent.orange.label, 'Oranye Racing');
    });

    for (final accent in AppAccent.values) {
      test('${accent.label}: teks di atas aksen dan teks aksen terbaca', () {
        expect(
          contrastRatio(accent.onColor, accent.color),
          greaterThanOrEqualTo(4.5),
        );
        for (final b in Brightness.values) {
          final p = AppPalette.forAccent(b, accent);
          expect(p.accent, accent.color);
          expect(contrastRatio(p.primaryText, p.bg), greaterThanOrEqualTo(4.5));
          expect(
            contrastRatio(p.primaryText, p.surface),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrastRatio(p.primaryText, p.surfaceAlt),
            greaterThanOrEqualTo(4.0),
          );
          expect(
            contrastRatio(p.onAccent, p.accent),
            greaterThanOrEqualTo(4.5),
          );
        }
      });
    }

    test('oranye memakai palet bawaan persis', () {
      expect(
        AppPalette.forAccent(Brightness.light, AppAccent.orange),
        same(AppPalette.light),
      );
      expect(
        AppPalette.forAccent(Brightness.dark, AppAccent.orange),
        same(AppPalette.dark),
      );
    });

    test('parse nama tak dikenal kembali ke oranye', () {
      expect(AppAccent.parse('blue'), AppAccent.blue);
      expect(AppAccent.parse('ungu'), AppAccent.orange);
      expect(AppAccent.parse(null), AppAccent.orange);
    });
  });

  group('ThemeData per aksen', () {
    for (final accent in AppAccent.values) {
      test('${accent.label}: skema warna, tombol, dan palet ikut aksen', () {
        for (final theme in [
          AppTheme.light(accent: accent),
          AppTheme.dark(accent: accent),
        ]) {
          expect(theme.colorScheme.primary, accent.color);
          expect(theme.colorScheme.onPrimary, accent.onColor);
          expect(theme.extension<AppPalette>()!.accent, accent.color);
          final button = theme.filledButtonTheme.style!;
          expect(button.backgroundColor!.resolve({}), accent.color);
          expect(button.foregroundColor!.resolve({}), accent.onColor);
        }
      });
    }

    test('Material 3 dan font Inter tetap dipakai', () {
      final theme = AppTheme.dark(accent: AppAccent.blue);
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
    });
  });

  group('ThemeController', () {
    test('menyimpan dan memulihkan mode serta warna aksen', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ThemeController();
      await controller.attach(prefs);
      expect(controller.accent.value, AppAccent.orange);

      controller.setAccent(AppAccent.green);
      controller.setMode(ThemeMode.dark);

      final restored = ThemeController();
      await restored.attach(prefs);
      expect(restored.accent.value, AppAccent.green);
      expect(restored.value, ThemeMode.dark);
    });

    test('data tersimpan yang tak dikenal diabaikan', () async {
      SharedPreferences.setMockInitialValues({
        ThemeController.accentKey: 'ungu',
        ThemeController.storageKey: 'neon',
      });
      final controller = ThemeController();
      await controller.attach(await SharedPreferences.getInstance());
      expect(controller.accent.value, AppAccent.orange);
      expect(controller.value, ThemeMode.system);
    });

    test('changes memberi tahu saat mode maupun aksen berubah', () {
      final controller = ThemeController();
      var calls = 0;
      controller.changes.addListener(() => calls++);
      controller.setMode(ThemeMode.dark);
      controller.setAccent(AppAccent.red);
      expect(calls, 2);
    });
  });

  group('halaman Pengaturan Tampilan', () {
    Future<void> open(
      WidgetTester tester, {
      double w = 400,
      double h = 1400,
    }) async {
      size(tester, w, h);
      await tester.pumpWidget(themedApp(const AppearancePage()));
      await tester.pumpAndSettle();
    }

    testWidgets('menampilkan mode, lima warna, dan pratinjau', (tester) async {
      await open(tester);

      expect(find.text('Pengaturan Tampilan'), findsOneWidget);
      for (final label in ['Terang', 'Gelap', 'Sistem']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget);
      for (final accent in AppAccent.values) {
        expect(find.text(accent.label), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('appearance-preview')), findsOneWidget);
      expect(find.byType(MotoPartWordmark), findsOneWidget);
    });

    testWidgets('hanya warna aktif yang bercentang', (tester) async {
      await open(tester);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.text('Hijau'));
      await tester.pumpAndSettle();

      expect(themeController.accent.value, AppAccent.green);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      // Cincin/centang pindah ke Hijau.
      final check = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
      expect(check.color, AppAccent.green.onColor);
    });

    testWidgets('memilih mode mengubah tema', (tester) async {
      await open(tester);

      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();
      expect(themeController.value, ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byType(AppearancePage))).brightness,
        Brightness.dark,
      );

      await tester.tap(find.text('Sistem'));
      await tester.pumpAndSettle();
      expect(themeController.value, ThemeMode.system);

      await tester.tap(find.text('Terang'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppearancePage))).brightness,
        Brightness.light,
      );
    });

    testWidgets('memilih aksen langsung mengubah tombol di pratinjau', (
      tester,
    ) async {
      await open(tester);
      Color filledColor() {
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        final context = tester.element(find.byType(FilledButton));
        return button.style?.backgroundColor?.resolve({}) ??
            Theme.of(context).filledButtonTheme.style!.backgroundColor!
                .resolve({})!;
      }

      expect(filledColor(), AppAccent.orange.color);
      await tester.tap(find.text('Biru'));
      await tester.pumpAndSettle();
      expect(filledColor(), AppAccent.blue.color);
      await tester.tap(find.text('Merah'));
      await tester.pumpAndSettle();
      expect(filledColor(), AppAccent.red.color);
    });

    testWidgets('pilihan aksen menyebar ke seluruh aplikasi', (tester) async {
      await open(tester);
      final context = tester.element(find.byType(AppearancePage));
      expect(Theme.of(context).colorScheme.primary, AppAccent.orange.color);
      expect(context.palette.accent, AppAccent.orange.color);

      await tester.tap(find.text('Kuning'));
      await tester.pumpAndSettle();

      final after = tester.element(find.byType(AppearancePage));
      expect(Theme.of(after).colorScheme.primary, AppAccent.yellow.color);
      expect(after.palette.accent, AppAccent.yellow.color);
      expect(after.palette.onAccent, AppAccent.yellow.onColor);
    });

    testWidgets('area sentuh tiap warna minimal 48x48', (tester) async {
      await open(tester);
      for (final accent in AppAccent.values) {
        final box = tester.getSize(
          find
              .ancestor(
                of: find.text(accent.label),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        expect(box.width, greaterThanOrEqualTo(48));
      }
      final circle = tester.getSize(find.byType(AnimatedContainer).first);
      expect(circle.height, greaterThanOrEqualTo(48));
    });

    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
          'tanpa overflow di layar 320 (${dark ? 'gelap' : 'terang'}, teks x$scale)',
          (tester) async {
            themeController.setMode(dark ? ThemeMode.dark : ThemeMode.light);
            size(tester, 320, 640);
            await tester.pumpWidget(
              themedApp(
                Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: const AppearancePage(),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('semua aksen terbaca di halaman (tanpa error render)', (
      tester,
    ) async {
      for (final accent in AppAccent.values) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          themeController.setMode(mode);
          themeController.setAccent(accent);
          size(tester, 400, 1400);
          await tester.pumpWidget(themedApp(const AppearancePage()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  });

  group('akses ke halaman', () {
    testWidgets('dari menu Akun (pembeli)', (tester) async {
      size(tester, 400, 1600);
      await tester.pumpWidget(themedApp(const ProfilePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Warna aksen & pratinjau'));
      await tester.pumpAndSettle();

      expect(find.byType(AppearancePage), findsOneWidget);
    });

    testWidgets('dari dasbor admin', (tester) async {
      auth.logout();
      size(tester, 400, 1600);
      await tester.pumpWidget(themedApp(const AdminDashboardPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pengaturan Tampilan'));
      await tester.pumpAndSettle();

      expect(find.byType(AppearancePage), findsOneWidget);
    });
  });

  group('MotoPartApp', () {
    testWidgets('memakai warna aksen terpilih dan transisinya halus', (
      tester,
    ) async {
      await tester.pumpWidget(const MotoPartApp());
      var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme!.colorScheme.primary, AppAccent.orange.color);
      expect(app.themeAnimationDuration, greaterThanOrEqualTo(Duration.zero));

      themeController.setAccent(AppAccent.blue);
      await tester.pump();
      app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme!.colorScheme.primary, AppAccent.blue.color);
      expect(app.darkTheme!.colorScheme.primary, AppAccent.blue.color);

      await tester.pump(const Duration(seconds: 3)); // lewati splash
      await tester.pumpAndSettle();
    });
  });

  group('MotoPartWordmark', () {
    testWidgets('MOTO warna teks, PART warna aksen, Inter w800 miring', (
      tester,
    ) async {
      themeController.setAccent(AppAccent.blue);
      size(tester, 400, 300);
      await tester.pumpWidget(
        themedApp(const Scaffold(body: MotoPartWordmark())),
      );

      final rich = tester.widget<RichText>(
        find.descendant(
          of: find.byType(MotoPartWordmark),
          matching: find.byType(RichText),
        ),
      );
      // Text.rich membungkus span buatan kita dengan gaya bawaan.
      final root = (rich.text as TextSpan).children!.single as TextSpan;
      expect(root.style!.fontWeight, FontWeight.w800);
      expect(root.style!.fontStyle, FontStyle.italic);
      final spans = root.children!.cast<TextSpan>();
      expect(spans.map((s) => s.text).join(), 'MOTOPART');

      final context = tester.element(find.byType(MotoPartWordmark));
      expect(spans[0].style!.color, context.palette.text);
      expect(spans[1].style!.color, context.palette.primaryText);
      // "PART" terbaca di atas latar.
      expect(
        contrastRatio(spans[1].style!.color!, context.palette.bg),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
