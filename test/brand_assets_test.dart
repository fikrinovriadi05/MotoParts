import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/app_logo.dart';
import 'package:motopart/widgets/brand_mark.dart';

/// Ukuran (lebar, tinggi) dan tipe warna dari header PNG.
({int w, int h, int colorType}) pngInfo(String path) {
  final bytes = File(path).readAsBytesSync();
  // Tanda tangan PNG.
  expect(bytes.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return (w: data.getUint32(16), h: data.getUint32(20), colorType: bytes[25]);
}

void expectSquarePng(String path, int px) {
  final info = pngInfo(path);
  expect(info.w, px, reason: '$path lebar');
  expect(info.h, px, reason: '$path tinggi');
}

void main() {
  group('widget logo', () {
    testWidgets('BrandMark menggambar tanpa error di berbagai ukuran', (
      tester,
    ) async {
      for (final size in [16.0, 48.0, 120.0, 400.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: BrandMark(size: size, withBackground: true)),
          ),
        );
        expect(tester.getSize(find.byType(BrandMark)), Size.square(size));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('BrandMark punya label aksesibilitas', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: BrandMark(size: 80))),
      );

      expect(find.bySemanticsLabel('Logo MotoPart'), findsOneWidget);
    });

    testWidgets('AppLogo menampilkan logo dan nama MotoPart', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: Center(child: AppLogo(size: 30))),
        ),
      );

      expect(find.byType(BrandMark), findsOneWidget);
      final text = tester.widget<RichText>(
        find.descendant(
          of: find.byType(AppLogo),
          matching: find.byType(RichText),
        ),
      );
      expect(text.text.toPlainText(), 'MotoPart');
    });

    test('shouldRepaint hanya saat parameter berubah', () {
      const a = BrandMarkPainter(withBackground: true, cornerRadius: 0.2);

      expect(
        a.shouldRepaint(
          const BrandMarkPainter(withBackground: true, cornerRadius: 0.2),
        ),
        isFalse,
      );
      expect(a.shouldRepaint(const BrandMarkPainter()), isTrue);
    });
  });

  group('berkas ikon hasil pembuat ikon', () {
    const res = 'android/app/src/main/res';

    test('Android: ikon lama di 5 kerapatan', () {
      const sizes = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final e in sizes.entries) {
        expectSquarePng('$res/mipmap-${e.key}/ic_launcher.png', e.value);
      }
    });

    test('Android: foreground adaptif 108dp di 5 kerapatan', () {
      const sizes = {
        'mdpi': 108,
        'hdpi': 162,
        'xhdpi': 216,
        'xxhdpi': 324,
        'xxxhdpi': 432,
      };
      for (final e in sizes.entries) {
        expectSquarePng(
          '$res/drawable-${e.key}/ic_launcher_foreground.png',
          e.value,
        );
      }
    });

    test('Android: lapisan monokrom (ikon bertema) 108dp di 5 kerapatan', () {
      const sizes = {
        'mdpi': 108,
        'hdpi': 162,
        'xhdpi': 216,
        'xxhdpi': 324,
        'xxxhdpi': 432,
      };
      for (final e in sizes.entries) {
        expectSquarePng(
          '$res/drawable-${e.key}/ic_launcher_monochrome.png',
          e.value,
        );
      }
      expect(
        File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync(),
        contains(
          '<monochrome android:drawable="@drawable/ic_launcher_monochrome"',
        ),
      );
    });

    test('BrandMarkPainter monokrom hanya memakai satu warna', () {
      const painter = BrandMarkPainter(monochrome: true);

      expect(painter.monochrome, isTrue);
      expect(
        painter.shouldRepaint(const BrandMarkPainter()),
        isTrue,
        reason: 'monokrom berbeda dari berwarna',
      );
    });

    test('Android: gambar splash 160dp di 5 kerapatan', () {
      const sizes = {
        'mdpi': 160,
        'hdpi': 240,
        'xhdpi': 320,
        'xxhdpi': 480,
        'xxxhdpi': 640,
      };
      for (final e in sizes.entries) {
        expectSquarePng('$res/drawable-${e.key}/splash_logo.png', e.value);
      }
    });

    test(
      'Android: XML ikon adaptif, warna latar, dan splash saling terhubung',
      () {
        final adaptive = File('$res/mipmap-anydpi-v26/ic_launcher.xml')
            .readAsStringSync();
        expect(adaptive, contains('@color/ic_launcher_background'));
        expect(adaptive, contains('@drawable/ic_launcher_foreground'));

        expect(
          File('$res/values/ic_launcher_background.xml').readAsStringSync(),
          contains('#FF1A1A1D'),
        );
        for (final path in [
          '$res/drawable/launch_background.xml',
          '$res/drawable-v21/launch_background.xml',
        ]) {
          final xml = File(path).readAsStringSync();
          expect(xml, contains('@color/ic_launcher_background'));
          expect(xml, contains('@drawable/splash_logo'));
        }
        for (final path in [
          '$res/values-v31/styles.xml',
          '$res/values-night-v31/styles.xml',
        ]) {
          final xml = File(path).readAsStringSync();
          expect(xml, contains('windowSplashScreenBackground'));
          expect(xml, contains('@drawable/splash_logo'));
        }
      },
    );

    test('nama aplikasi di ponsel: MotoPart', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();

      expect(manifest, contains('android:label="MotoPart"'));
      expect(manifest, contains('@mipmap/ic_launcher'));
    });

    test('iOS: semua ikon di Contents.json ada, ukuran benar, tanpa alpha', () {
      const dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final contents = jsonDecode(
        File('$dir/Contents.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final images = (contents['images'] as List).cast<Map<String, dynamic>>();
      expect(images, isNotEmpty);

      for (final image in images) {
        final name = image['filename'] as String;
        final points = double.parse((image['size'] as String).split('x').first);
        final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
        final expected = (points * scale).round();

        final info = pngInfo('$dir/$name');
        expect(info.w, expected, reason: name);
        expect(info.h, expected, reason: name);
        expect(info.colorType, 2, reason: '$name harus RGB tanpa alpha');
      }
    });

    test('macOS: ikon 16 sampai 1024', () {
      for (final px in [16, 32, 64, 128, 256, 512, 1024]) {
        expectSquarePng(
          'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$px.png',
          px,
        );
      }
    });

    test('Web: favicon, ikon 192/512, dan maskable', () {
      expectSquarePng('web/favicon.png', 32);
      for (final px in [192, 512]) {
        expectSquarePng('web/icons/Icon-$px.png', px);
        expectSquarePng('web/icons/Icon-maskable-$px.png', px);
      }
      expect(
        File('web/manifest.json').readAsStringSync(),
        contains('"name": "MotoPart"'),
      );
    });

    test('Windows: app_icon.ico valid berisi 7 gambar PNG', () {
      final bytes = File('windows/runner/resources/app_icon.ico')
          .readAsBytesSync();
      final data = ByteData.sublistView(bytes);

      expect(data.getUint16(0, Endian.little), 0); // reserved
      expect(data.getUint16(2, Endian.little), 1); // tipe: ikon
      final count = data.getUint16(4, Endian.little);
      expect(count, 7);

      final sizes = <int>[];
      for (var i = 0; i < count; i++) {
        final entry = 6 + 16 * i;
        final w = data.getUint8(entry);
        sizes.add(w == 0 ? 256 : w);
        final length = data.getUint32(entry + 8, Endian.little);
        final offset = data.getUint32(entry + 12, Endian.little);
        expect(offset + length, lessThanOrEqualTo(bytes.length));
        // Setiap gambar berupa PNG.
        expect(bytes.sublist(offset + 1, offset + 4), [0x50, 0x4E, 0x47]);
      }
      expect(sizes, [16, 24, 32, 48, 64, 128, 256]);
    });

    test('contoh logo tersimpan di tool/brand', () {
      expectSquarePng('tool/brand/logo_1024.png', 1024);
      expectSquarePng('tool/brand/logo_mark_1024.png', 1024);
    });
  });
}
