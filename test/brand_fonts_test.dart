import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/app_logo.dart';

/// Bobot font yang tersedia di folder fonts/ (Inter).
const bundledWeights = {400, 500, 600, 700, 800, 900};

void main() {
  late String pubspec;
  setUpAll(() => pubspec = File('pubspec.yaml').readAsStringSync());

  group('font disertakan di aplikasi (offline)', () {
    test('Inter 400-900 terdaftar di pubspec', () {
      expect(pubspec, contains('family: Inter'));
      for (final file in [
        'Inter-Regular',
        'Inter-Medium',
        'Inter-SemiBold',
        'Inter-Bold',
        'Inter-ExtraBold',
        'Inter-Black',
      ]) {
        expect(pubspec, contains('asset: fonts/$file.ttf'), reason: file);
      }
      for (final weight in [500, 600, 700, 800, 900]) {
        expect(pubspec, contains('weight: $weight'), reason: 'bobot $weight');
      }
    });

    test('font lama (Poppins/Montserrat) sudah tidak dipakai', () {
      expect(pubspec.contains('Poppins'), isFalse);
      expect(pubspec.contains('Montserrat'), isFalse);
      final names = Directory('fonts').listSync().map((e) => e.path).toList();
      expect(names.any((n) => n.contains('Poppins')), isFalse);
      expect(names.any((n) => n.contains('Montserrat')), isFalse);
    });

    test('semua berkas font ada dan berformat TrueType', () {
      final fonts = Directory('fonts')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ttf'))
          .toList();

      expect(fonts.length, 6);
      for (final f in fonts) {
        final head = f.readAsBytesSync().sublist(0, 4);
        expect(head, [0x00, 0x01, 0x00, 0x00], reason: f.path);
        expect(f.lengthSync(), greaterThan(50 * 1024), reason: f.path);
      }
    });

    test('lisensi OFL disertakan dan didaftarkan di main.dart', () {
      final file = File('fonts/OFL-Inter.txt');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));

      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('LicenseRegistry.addLicense'));
      expect(main, contains('fonts/OFL-Inter.txt'));
    });

    test('San Francisco tidak disertakan di aplikasi (lisensi Apple)', () {
      final names = Directory('fonts').listSync().map((e) => e.path).toList();

      expect(names.any((n) => n.toLowerCase().contains('sf-')), isFalse);
      expect(
        names.any((n) => n.toLowerCase().contains('sanfrancisco')),
        isFalse,
      );
      expect(pubspec.toLowerCase().contains('sf pro'), isFalse);
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

    test('semua FontWeight di kode tersedia di berkas font Inter', () {
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
        reason: 'bobot ${used.difference(bundledWeights)} tidak punya berkas',
      );
    });
  });

  group('tema: Inter di Android dan platform lain', () {
    setUp(() => UiConfig.useBrandFonts = true);
    tearDown(() => UiConfig.useBrandFonts = false);

    test('semua gaya teks memakai Inter', () {
      final text = AppTheme.light().textTheme;

      for (final style in [
        text.bodyLarge,
        text.bodyMedium,
        text.labelLarge,
        text.titleLarge,
        text.headlineSmall,
        text.displaySmall,
      ]) {
        expect(style?.fontFamily, 'Inter');
      }
    });

    test('judul tebal (w700) dengan jarak huruf sedikit rapat', () {
      final text = AppTheme.dark().textTheme;

      for (final style in [
        text.titleLarge,
        text.headlineSmall,
        text.headlineMedium,
        text.displaySmall,
      ]) {
        expect(style?.fontWeight, FontWeight.w700);
        expect(style!.letterSpacing, lessThan(0));
      }
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
      expect((rich.text as TextSpan).style?.fontFamily, 'Inter');
    });
  });

  group('tema: San Francisco asli di iOS dan macOS', () {
    setUp(() => UiConfig.useBrandFonts = true);
    tearDown(() {
      UiConfig.useBrandFonts = false;
      debugDefaultTargetPlatformOverride = null;
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      test('${platform.name}: memakai font sistem, bukan Inter', () {
        debugDefaultTargetPlatformOverride = platform;

        expect(UiConfig.usesSystemFont, isTrue);
        final text = AppTheme.light().textTheme;
        expect(text.bodyMedium?.fontFamily, isNot('Inter'));
        expect(text.titleLarge?.fontFamily, isNot('Inter'));
        // Font sistem Apple (San Francisco), mis. ".SF Pro Text".
        expect(
          text.bodyMedium?.fontFamily?.toLowerCase(),
          anyOf(contains('sf'), contains('system')),
        );
      });
    }

    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      test('${platform.name}: memakai Inter', () {
        debugDefaultTargetPlatformOverride = platform;

        expect(UiConfig.usesSystemFont, isFalse);
        expect(AppTheme.light().textTheme.bodyMedium?.fontFamily, 'Inter');
      });
    }
  });

  group('tes memakai font Ahem', () {
    test('flag useBrandFonts mati di tes: tanpa fontFamily merek', () {
      expect(UiConfig.useBrandFonts, isFalse);
      expect(AppTheme.light().textTheme.bodyMedium?.fontFamily, isNot('Inter'));
    });
  });
}
