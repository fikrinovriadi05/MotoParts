// Pembuat ikon & splash MotoPart dari logo yang digambar lewat kode.
//
// Jalankan dari folder proyek:
//   flutter test tool/generate_icons_test.dart
//
// Menimpa file ikon di android/, ios/, macos/, web/, windows/ dan menyimpan
// contoh logo di tool/brand/. Bukan bagian dari `flutter test` biasa.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/widgets/brand_mark.dart';

/// Merender logo ke PNG berukuran [px] x [px].
Future<Uint8List> renderPng(
  int px, {
  bool background = true,
  double cornerRadius = 0,
  double contentScale = 1,
  bool monochrome = false,

  /// Skala keseluruhan ikon di dalam kanvas transparan (gaya ikon macOS).
  double inset = 1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final painter = BrandMarkPainter(
    withBackground: background,
    cornerRadius: cornerRadius,
    contentScale: contentScale,
    monochrome: monochrome,
  );
  final inner = px * inset;
  canvas.translate((px - inner) / 2, (px - inner) / 2);
  painter.paint(canvas, ui.Size(inner, inner));
  final image = await recorder.endRecording().toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Merender logo lalu menyandikannya sebagai PNG RGB **tanpa kanal alpha**
/// (App Store menolak ikon iOS yang punya transparansi).
Future<Uint8List> renderOpaquePng(
  int px, {
  double cornerRadius = 0,
  double contentScale = 1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  BrandMarkPainter(
    withBackground: true,
    cornerRadius: cornerRadius,
    contentScale: contentScale,
  ).paint(canvas, ui.Size(px.toDouble(), px.toDouble()));
  final image = await recorder.endRecording().toImage(px, px);
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  return encodeRgbPng(rgba, px, px);
}

final _crcTable = () {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}();

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

List<int> _chunk(String type, List<int> data) {
  final body = [...ascii.encode(type), ...data];
  final out = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32(body));
  return [...out.buffer.asUint8List(), ...body, ...crc.buffer.asUint8List()];
}

/// PNG 8-bit RGB (tipe warna 2) dari piksel RGBA; kanal alpha dibuang.
Uint8List encodeRgbPng(Uint8List rgba, int width, int height) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      raw.add([rgba[i], rgba[i + 1], rgba[i + 2]]);
    }
  }
  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // kedalaman bit
    ..setUint8(9, 2) // RGB
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // tanda tangan PNG
    ..._chunk('IHDR', ihdr.buffer.asUint8List()),
    ..._chunk('IDAT', ZLibEncoder().convert(raw.toBytes())),
    ..._chunk('IEND', const []),
  ]);
}

void write(String path, Uint8List bytes) {
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}

/// Membuat file .ico berisi gambar PNG (didukung Windows Vista ke atas).
Uint8List buildIco(Map<int, Uint8List> pngBySize) {
  final sizes = pngBySize.keys.toList()..sort();
  final header = ByteData(6 + 16 * sizes.length);
  header.setUint16(0, 0, Endian.little); // reserved
  header.setUint16(2, 1, Endian.little); // type: icon
  header.setUint16(4, sizes.length, Endian.little);
  var offset = header.lengthInBytes;
  for (var i = 0; i < sizes.length; i++) {
    final size = sizes[i];
    final png = pngBySize[size]!;
    final entry = 6 + 16 * i;
    header.setUint8(entry, size >= 256 ? 0 : size);
    header.setUint8(entry + 1, size >= 256 ? 0 : size);
    header.setUint8(entry + 2, 0); // palette
    header.setUint8(entry + 3, 0);
    header.setUint16(entry + 4, 1, Endian.little); // planes
    header.setUint16(entry + 6, 32, Endian.little); // bpp
    header.setUint32(entry + 8, png.length, Endian.little);
    header.setUint32(entry + 12, offset, Endian.little);
    offset += png.length;
  }
  final out = BytesBuilder()..add(header.buffer.asUint8List());
  for (final size in sizes) {
    out.add(pngBySize[size]!);
  }
  return out.toBytes();
}

void main() {
  testWidgets('buat semua ikon dan gambar splash', (tester) async {
    await tester.runAsync(() async {
      const res = 'android/app/src/main/res';

      // Contoh logo untuk dokumentasi.
      write(
        'tool/brand/logo_1024.png',
        await renderPng(1024, cornerRadius: 0.22, contentScale: 0.92),
      );
      write(
        'tool/brand/logo_mark_1024.png',
        await renderPng(1024, background: false),
      );

      // --- Android: ikon lama (persegi membulat) -------------------------
      const legacy = {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      };
      for (final e in legacy.entries) {
        write(
          '$res/mipmap-${e.key}/ic_launcher.png',
          await renderPng(e.value, cornerRadius: 0.22, contentScale: 0.92),
        );
      }

      // --- Android: ikon adaptif (latar warna + foreground transparan) ---
      const adaptive = {
        'mdpi': 108,
        'hdpi': 162,
        'xhdpi': 216,
        'xxhdpi': 324,
        'xxxhdpi': 432,
      };
      for (final e in adaptive.entries) {
        write(
          '$res/drawable-${e.key}/ic_launcher_foreground.png',
          // Zona aman adaptif = 66% tengah; logo dibuat sedikit di dalamnya.
          await renderPng(e.value, background: false, contentScale: 0.68),
        );
      }

      // --- Android 13+: lapisan monokrom untuk ikon bertema --------------
      for (final e in adaptive.entries) {
        write(
          '$res/drawable-${e.key}/ic_launcher_monochrome.png',
          await renderPng(
            e.value,
            background: false,
            contentScale: 0.68,
            monochrome: true,
          ),
        );
      }

      // --- Android: gambar splash (tanpa latar, dipusatkan) --------------
      const splash = {
        'mdpi': 160,
        'hdpi': 240,
        'xhdpi': 320,
        'xxhdpi': 480,
        'xxxhdpi': 640,
      };
      for (final e in splash.entries) {
        write(
          '$res/drawable-${e.key}/splash_logo.png',
          // Android 12+ memotong gambar splash menjadi lingkaran (2/3 tengah),
          // jadi logo diberi ruang agar roda giginya tidak terpotong.
          await renderPng(e.value, background: false, contentScale: 0.62),
        );
      }

      // --- iOS: penuh tanpa transparansi (sistem yang membulatkan) -------
      const iosSizes = {
        'Icon-App-20x20@1x': 20,
        'Icon-App-20x20@2x': 40,
        'Icon-App-20x20@3x': 60,
        'Icon-App-29x29@1x': 29,
        'Icon-App-29x29@2x': 58,
        'Icon-App-29x29@3x': 87,
        'Icon-App-40x40@1x': 40,
        'Icon-App-40x40@2x': 80,
        'Icon-App-40x40@3x': 120,
        'Icon-App-60x60@2x': 120,
        'Icon-App-60x60@3x': 180,
        'Icon-App-76x76@1x': 76,
        'Icon-App-76x76@2x': 152,
        'Icon-App-83.5x83.5@2x': 167,
        'Icon-App-1024x1024@1x': 1024,
      };
      for (final e in iosSizes.entries) {
        write(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/${e.key}.png',
          await renderOpaquePng(e.value, contentScale: 0.9),
        );
      }

      // --- macOS: persegi membulat dengan margin transparan --------------
      for (final px in [16, 32, 64, 128, 256, 512, 1024]) {
        write(
          'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$px.png',
          await renderPng(
            px,
            cornerRadius: 0.22,
            contentScale: 0.92,
            inset: 0.82,
          ),
        );
      }

      // --- Web ------------------------------------------------------------
      write(
        'web/favicon.png',
        await renderPng(32, cornerRadius: 0.22, contentScale: 0.94),
      );
      for (final px in [192, 512]) {
        write(
          'web/icons/Icon-$px.png',
          await renderPng(px, cornerRadius: 0.22, contentScale: 0.92),
        );
        write(
          'web/icons/Icon-maskable-$px.png',
          await renderPng(px, contentScale: 0.72),
        );
      }

      // --- Windows --------------------------------------------------------
      final ico = <int, Uint8List>{
        for (final px in [16, 24, 32, 48, 64, 128, 256])
          px: await renderPng(px, cornerRadius: 0.22, contentScale: 0.94),
      };
      write('windows/runner/resources/app_icon.ico', buildIco(ico));
    });

    expect(File('tool/brand/logo_1024.png').existsSync(), isTrue);
  });
}
