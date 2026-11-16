import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/app_logo.dart';

/// Bobot font yang tersedia di folder fonts/ (Poppins).
const bundledWeights = {400, 500, 600, 700, 800, 900};

void main() {
  late String pubspec;
  setUpAll(() => pubspec = File('pubspec.yaml').readAsStringSync());

  group('font disertakan di aplikasi (offline)', () {
    test('Poppins 400-900 dan Montserrat 700/800 terdaftar di pubspec', () {
      expect(pubspec, contains('family: Poppins'));
      expect(pubspec, contains('family: Montserrat'));
      for (final file in [
        'Poppins-Regular',
        'Poppins-Medium',
        'Poppins-SemiBold',
        'Poppins-Bold',
        'Poppins-ExtraBold',
        'Poppins-Black',
        'Montserrat-Bold',
        'Montserrat-ExtraBold',
      ]) {
        expect(pubspec, contains('asset: fonts/$file.ttf'), reason: file);
      }
    });

    test('semua berkas font ada dan berformat TrueType', () {
      final fonts = Directory('fonts')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ttf'))
          .toList();

      expect(fonts.length, 8);
      for (final f in fonts) {
        final head = f.readAsBytesSync().sublist(0, 4);
        expect(head, [0x00, 0x01, 0x00, 0x00], reason: f.path);
        expect(f.lengthSync(), greaterThan(50 * 1024), reason: f.path);
      }
    });

    test('lisensi OFL disertakan dan didaftarkan di main.dart', () {
      for (final name in ['OFL-Poppins', 'OFL-Montserrat']) {
        final file = File('fonts/$name.txt');
        expect(file.existsSync(), isTrue, reason: name);
        expect(file.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
      }
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('LicenseRegistry.addLicense'));
      expect(main, contains('fonts/OFL-Poppins.txt'));
      expect(main, contains('fonts/OFL-Montserrat.txt'));
    });

    test('tidak lagi bergantung pada google_fonts (tanpa izin internet)', () {
      expect(pubspec.contains('google_fonts:'), isFalse);
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final f in sources) {
        expect(
          f.readAsStringSync().contains('package:google_fonts'),
          isFalse,
          reason: f.path,
        );
      }
    });

    test('semua FontWeight di kode tersedia di berkas font Poppins', () {
      final used = <int>{};
      final pattern = RegExp(r'FontWeight\.w(\d)00');
      for (final f
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        for (final m in pattern.allMatches(f.readAsStringSync())) {
          used.add(int.parse(m.group(1)!) * 100);
        }
      }

      expect(used, isNotEmpty);
      expect(
        used.difference(bundledWeights),
        isEmpty,
        reason:
            'bobot ${used.difference(bundledWeights)} tidak punya berkas font',
      );
    });
  });

  group('tema memakai font merek', () {
    setUp(() => UiConfig.useBrandFonts = true);
    tearDown(() => UiConfig.useBrandFonts = false);

    test('teks Poppins, judul Montserrat ExtraBold', () {
      final theme = AppTheme.light();
      final text = theme.textTheme;

      expect(text.bodyMedium?.fontFamily, 'Poppins');
      expect(text.labelLarge?.fontFamily, 'Poppins');
      for (final style in [
        text.titleLarge,
        text.headlineSmall,
        text.headlineMedium,
        text.displaySmall,
      ]) {
        expect(style?.fontFamily, 'Montserrat');
        expect(style?.fontWeight, FontWeight.w800);
      }
    });

    test('mode gelap memakai font yang sama', () {
      expect(AppTheme.dark().textTheme.bodyMedium?.fontFamily, 'Poppins');
    });

    testWidgets('AppLogo mewarisi font tema (bukan font bawaan sistem)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: Center(child: AppLogo())),
        ),
      );

      final rich = tester.widget<RichText>(
        find.descendant(
          of: find.byType(AppLogo),
          matching: find.byType(RichText),
        ),
      );
      expect((rich.text as TextSpan).style?.fontFamily, 'Poppins');
    });
  });

  group('tes memakai font Ahem', () {
    test('flag useBrandFonts mati di tes: tanpa fontFamily merek', () {
      expect(UiConfig.useBrandFonts, isFalse);
      expect(
        AppTheme.light().textTheme.bodyMedium?.fontFamily,
        isNot('Poppins'),
      );
    });
  });
}
