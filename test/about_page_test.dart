import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/app_info.dart';
import 'package:motopart/pages/user/about_page.dart';
import 'package:motopart/pages/user/profile_page.dart';
import 'package:motopart/theme/app_theme.dart';

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('AppInfo', () {
    test('nama kelompok dan anggota sesuai data', () {
      expect(AppInfo.groupName, 'Kelompok Mobile Programming Moto Part');
      expect(
        [for (final m in AppInfo.members) (m.name, m.nim)],
        [
          ('Fikri Novriadi', '24101152610051'),
          ('Irfandi Ramadhan', '24101152610055'),
          ('Rafly Antoni Saputra', '24101152610067'),
          ('Muzakki Fernando', '24101152610063'),
        ],
      );
    });

    test('NIM unik dan semuanya 14 angka', () {
      final nims = [for (final m in AppInfo.members) m.nim];
      expect(nims.toSet().length, nims.length);
      for (final nim in nims) {
        expect(RegExp(r'^\d{14}$').hasMatch(nim), isTrue, reason: nim);
      }
    });

    test('versi sama dengan pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*([\d.]+)\+\d+',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(match, isNotNull);
      expect(AppInfo.version, match!.group(1));
    });
  });

  group('AboutPage', () {
    Future<void> pump(WidgetTester tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const AboutPage()),
      );
    }

    testWidgets('menampilkan nama kelompok, versi, dan semua anggota', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Tentang MotoPart'), findsOneWidget); // judul
      expect(
        find.text('Kelompok Mobile Programming Moto Part'),
        findsOneWidget,
      );
      expect(find.text('Versi ${AppInfo.version}'), findsOneWidget);
      expect(find.text('Anggota:'), findsOneWidget);
      for (final member in AppInfo.members) {
        expect(find.text(member.name), findsOneWidget, reason: member.name);
        expect(find.text(member.nim), findsOneWidget, reason: member.nim);
      }
    });

    testWidgets('anggota bernomor 1 sampai 4 berurutan', (tester) async {
      await pump(tester);

      for (var i = 1; i <= 4; i++) {
        expect(find.text('$i'), findsOneWidget, reason: 'nomor $i');
      }
      // Urutan tampil sama dengan urutan data (dari atas ke bawah).
      final dy = [
        for (final m in AppInfo.members)
          tester.getTopLeft(find.text(m.name)).dy,
      ];
      final sorted = [...dy]..sort();
      expect(dy, sorted);
    });

    testWidgets('tombol lisensi membuka halaman lisensi', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Lisensi sumber terbuka'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('dibuka dari menu Tentang MotoPart di halaman Akun', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const ProfilePage()),
      );

      await tester.scrollUntilVisible(
        find.text('Tentang MotoPart'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Tentang MotoPart'));
      await tester.pumpAndSettle();

      expect(find.byType(AboutPage), findsOneWidget);
      expect(find.text('Muzakki Fernando'), findsOneWidget);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'tidak ada overflow di layar kecil (${mode.name}, teks 1.3x)',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              home: const AboutPage(),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
