import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const appId = 'id.motopart.app';

String read(String path) => File(path).readAsStringSync();

void main() {
  group('nama paket (application ID)', () {
    test('Android: namespace dan applicationId', () {
      final gradle = read('android/app/build.gradle.kts');

      expect(gradle, contains('namespace = "$appId"'));
      expect(gradle, contains('applicationId = "$appId"'));
    });

    test('MainActivity ada di folder paket baru dan paket cocok', () {
      final file = File(
        'android/app/src/main/kotlin/id/motopart/app/MainActivity.kt',
      );

      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('package $appId'));
      expect(
        Directory('android/app/src/main/kotlin/com').existsSync(),
        isFalse,
        reason: 'folder paket lama harus sudah dihapus',
      );
    });

    test('iOS: semua bundle identifier memakai nama paket baru', () {
      final lines = read('ios/Runner.xcodeproj/project.pbxproj')
          .split('\n')
          .where((l) => l.contains('PRODUCT_BUNDLE_IDENTIFIER'))
          .toList();

      expect(lines, isNotEmpty);
      for (final l in lines) {
        expect(l, contains(appId), reason: l);
      }
    });

    test('macOS, Linux, dan Windows memakai nama baru', () {
      expect(
        read('macos/Runner/Configs/AppInfo.xcconfig'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = $appId'),
      );
      expect(read('linux/CMakeLists.txt'), contains('"$appId"'));
      expect(read('windows/runner/Runner.rc'), contains('"MotoPart"'));
    });

    test('tidak ada sisa "com.example" di berkas konfigurasi platform', () {
      const files = [
        'android/app/build.gradle.kts',
        'android/app/src/main/AndroidManifest.xml',
        'ios/Runner.xcodeproj/project.pbxproj',
        'ios/Runner/Info.plist',
        'macos/Runner.xcodeproj/project.pbxproj',
        'macos/Runner/Configs/AppInfo.xcconfig',
        'linux/CMakeLists.txt',
        'windows/runner/Runner.rc',
      ];
      for (final f in files) {
        expect(read(f).contains('com.example'), isFalse, reason: f);
      }
    });
  });

  group('penandatanganan rilis Android', () {
    test('build.gradle.kts memakai key.properties dengan cadangan debug', () {
      final gradle = read('android/app/build.gradle.kts');

      expect(gradle, contains('rootProject.file("key.properties")'));
      expect(gradle, contains('signingConfigs.getByName("release")'));
      expect(
        gradle,
        contains('signingConfigs.getByName("debug")'),
        reason: 'tanpa key.properties build rilis tetap bisa dijalankan',
      );
      expect(gradle, contains('keystoreProperties["storePassword"]'));
    });

    test('keystore dan key.properties diabaikan git', () {
      final ignore = read('android/.gitignore');

      expect(ignore, contains('key.properties'));
      expect(ignore, contains('*.jks'));
      expect(ignore, contains('*.keystore'));
    });

    test('keystore dan key.properties tidak terlacak git', () async {
      final result = await Process.run('git', [
        'ls-files',
        '--',
        'android/key.properties',
        '*.jks',
        '*.keystore',
      ]);
      if (result.exitCode != 0) return; // bukan repo git / git tidak ada

      expect((result.stdout as String).trim(), isEmpty);
    });

    test('jika key.properties ada: lengkap dan menunjuk ke keystore', () {
      final file = File('android/key.properties');
      if (!file.existsSync()) return; // mesin lain tanpa kunci rilis

      final props = {
        for (final line in file.readAsLinesSync())
          if (line.contains('='))
            line.substring(0, line.indexOf('=')): line.substring(
              line.indexOf('=') + 1,
            ),
      };

      for (final key in [
        'storePassword',
        'keyPassword',
        'keyAlias',
        'storeFile',
      ]) {
        expect(props[key], isNotNull, reason: key);
        expect(props[key], isNotEmpty, reason: key);
      }
      expect(File('android/app/${props['storeFile']}').existsSync(), isTrue);
      expect(props['storePassword']!.length, greaterThanOrEqualTo(16));
    });
  });
}
