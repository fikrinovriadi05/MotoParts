import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/app.dart';
import 'package:motopart/pages/admin/admin_dashboard_page.dart';
import 'package:motopart/pages/auth/splash_page.dart';
import 'package:motopart/theme/app_theme.dart';

void main() {
  group('Lebar isi aplikasi (MotoPartApp)', () {
    Future<void> pumpApp(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MotoPartApp());
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('layar sangat lebar: isi dibatasi dan berada di tengah', (
      tester,
    ) async {
      await pumpApp(tester, const Size(1800, 900));

      final box = tester.getRect(find.byType(SplashPage));
      expect(box.width, MotoPartApp.maxContentWidth);
      expect(box.center.dx, closeTo(900, 0.5));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('di dalam bingkai: MediaQuery melaporkan lebar bingkai', (
      tester,
    ) async {
      await pumpApp(tester, const Size(1800, 900));

      final context = tester.element(find.byType(SplashPage));
      expect(MediaQuery.sizeOf(context).width, MotoPartApp.maxContentWidth);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('layar lebar: latar luar berbeda dan ada bayangan tepi', (
      tester,
    ) async {
      await pumpApp(tester, const Size(1800, 900));

      expect(find.byType(ClipRect), findsWidgets);
      final shadow = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty);
      expect(shadow, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('layar tepat selebar batas: tanpa bingkai', (tester) async {
      await pumpApp(tester, const Size(1100, 900));

      expect(tester.getSize(find.byType(SplashPage)).width, 1100);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('layar lebih sempit dari batas: isi memenuhi layar', (
      tester,
    ) async {
      await pumpApp(tester, const Size(800, 900));

      expect(tester.getSize(find.byType(SplashPage)).width, 800);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('layar HP: tidak berubah', (tester) async {
      await pumpApp(tester, const Size(390, 844));

      expect(tester.getSize(find.byType(SplashPage)).width, 390);
      await tester.pumpWidget(const SizedBox());
    });

    test('batas lebar 1100', () {
      expect(MotoPartApp.maxContentWidth, 1100);
    });
  });

  group('Dashboard admin di layar lebar', () {
    testWidgets('kartu statistik 4 kolom setinggi tetap 136', (tester) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const AdminDashboardPage()),
      );
      await tester.pump(const Duration(seconds: 2));

      final card = tester.getSize(
        find
            .ancestor(
              of: find.text('Total Produk'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(card.height, 136);
      expect(card.width, greaterThan(card.height)); // melebar, bukan menjulang
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('layar HP: 2 kolom dengan rasio 1,25', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const AdminDashboardPage()),
      );
      await tester.pump(const Duration(seconds: 2));

      final card = tester.getSize(
        find
            .ancestor(
              of: find.text('Total Produk'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(card.width / card.height, closeTo(1.25, 0.05));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
