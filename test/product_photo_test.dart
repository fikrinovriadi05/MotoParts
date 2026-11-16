import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/product_image_storage.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/admin/admin_products_page.dart';
import 'package:motopart/pages/user/product_detail_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/product_card.dart';
import 'package:motopart/widgets/product_picture.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PNG 1x1 yang valid.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Penyimpanan palsu: mengembalikan jalur yang disiapkan dan mencatat hapus.
class FakeImageStorage implements ProductImageStorage {
  final List<String> toPick = [];
  final List<String?> deleted = [];

  @override
  Future<String?> pickFromGallery() async =>
      toPick.isEmpty ? null : toPick.removeAt(0);

  @override
  Future<void> delete(String? path) async => deleted.add(path);
}

late Directory tmp;
var counter = 0;

/// Membuat file foto PNG valid di folder sementara.
String newPhoto() {
  final file = File('${tmp.path}/product_images/foto_${counter++}.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(_pngBytes);
  return file.path;
}

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

void size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late FakeImageStorage fake;
  late ProductImageStorage original;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('motopart_foto_');
    fake = FakeImageStorage();
    original = productImageStorage;
    productImageStorage = fake;
    final fresh = Store();
    store.products
      ..clear()
      ..addAll(fresh.products);
    store.cart.clear();
  });

  tearDown(() {
    productImageStorage = original;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('model dan penyimpanan', () {
    Product sample({String? imagePath}) => Product(
      id: 77,
      name: 'Produk Foto',
      category: 'Mesin',
      type: 'Universal',
      price: 1000,
      stock: 3,
      icon: Icons.build_rounded,
      description: 'd',
      imagePath: imagePath,
    );

    test('imagePath ikut toJson/fromJson', () {
      final restored = Product.fromJson(sample(imagePath: '/a/b.png').toJson());

      expect(restored.imagePath, '/a/b.png');
    });

    test('data lama tanpa imagePath tetap terbaca (null)', () {
      final json = sample().toJson()..remove('imagePath');

      expect(Product.fromJson(json).imagePath, isNull);
    });

    test('updateProduct: set, biarkan, dan hapus foto', () {
      final s = Store();
      final p = s.products[0];

      s.updateProduct(p, imagePath: '/x/foto.png');
      expect(p.imagePath, '/x/foto.png');

      s.updateProduct(p, name: 'Nama Baru'); // tanpa menyebut foto
      expect(p.imagePath, '/x/foto.png');

      s.updateProduct(p, clearImage: true);
      expect(p.imagePath, isNull);
    });

    test('jalur foto tersimpan permanen dan dimuat kembali', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = Store();
      await first.attach(prefs);
      first.updateProduct(first.products[2], imagePath: '/x/busi.png');

      final reloaded = Store();
      await reloaded.attach(prefs);

      expect(reloaded.products[2].imagePath, '/x/busi.png');
      expect(reloaded.products[0].imagePath, isNull);
    });
  });

  group('DeviceProductImageStorage', () {
    test('isManagedPath hanya untuk folder product_images', () {
      expect(
        DeviceProductImageStorage.isManagedPath(
          '/data/app/product_images/a.jpg',
        ),
        isTrue,
      );
      expect(
        DeviceProductImageStorage.isManagedPath(
          r'C:\data\product_images\a.jpg',
        ),
        isTrue,
      );
      expect(
        DeviceProductImageStorage.isManagedPath('/sdcard/DCIM/a.jpg'),
        isFalse,
      );
    });

    test(
      'delete menghapus file di folder foto, mengabaikan yang lain',
      () async {
        final storage = DeviceProductImageStorage();
        final managed = newPhoto();
        final outside = File('${tmp.path}/luar.png')
          ..writeAsBytesSync(_pngBytes);

        await storage.delete(managed);
        await storage.delete(outside.path);
        await storage.delete(null);
        await storage.delete('${tmp.path}/product_images/tidak_ada.png');

        expect(File(managed).existsSync(), isFalse);
        expect(
          outside.existsSync(),
          isTrue,
          reason: 'di luar folder: dibiarkan',
        );
      },
    );
  });

  group('ProductPicture', () {
    Future<void> pump(WidgetTester tester, String? path) {
      size(tester, 400, 400);
      return tester.pumpWidget(
        app(
          Scaffold(
            body: ProductPicture(
              imagePath: path,
              icon: Icons.settings_rounded,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );
    }

    testWidgets('tanpa foto: ikon', (tester) async {
      await pump(tester, null);

      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('foto ada: menampilkan gambar dari file', (tester) async {
      final path = newPhoto();
      await pump(tester, path);

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<FileImage>());
      expect((image.image as FileImage).file.path, path);
    });

    testWidgets('file hilang: kembali ke ikon tanpa error', (tester) async {
      await pump(tester, '${tmp.path}/product_images/hilang.png');

      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('file rusak: errorBuilder menampilkan ikon pengganti', (
      tester,
    ) async {
      final bad = File('${tmp.path}/product_images/rusak.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3, 4]);
      await pump(tester, bad.path);

      // Decode gambar rusak gagal secara asinkron; yang diuji: Image memiliki
      // errorBuilder yang menghasilkan ikon pengganti.
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.errorBuilder, isNotNull);
      final element = tester.element(find.byType(Image));
      final fallback = image.errorBuilder!(element, Exception('rusak'), null);
      await tester.pumpWidget(app(Scaffold(body: fallback)));

      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });

    test('hasPhoto', () {
      expect(ProductPicture.hasPhoto(null), isFalse);
      expect(ProductPicture.hasPhoto('${tmp.path}/nope.png'), isFalse);
      expect(ProductPicture.hasPhoto(newPhoto()), isTrue);
    });

    test('forProduct: produk null memakai ikon umum', () {
      final picture = ProductPicture.forProduct(null);

      expect(picture.icon, Icons.inventory_2_rounded);
      expect(picture.imagePath, isNull);
    });
  });

  group('tampilan di aplikasi', () {
    testWidgets('kartu produk memakai foto jika ada', (tester) async {
      size(tester, 400, 600);
      final p = store.products[0];
      p.imagePath = newPhoto();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: ProductCard.extent,
                child: ProductCard(product: p, onTap: () {}),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(p.icon), findsNothing);
    });

    testWidgets('halaman detail memakai foto dan tetap punya Hero', (
      tester,
    ) async {
      size(tester, 400, 1200);
      final p = store.products[0];
      p.imagePath = newPhoto();
      await tester.pumpWidget(app(ProductDetailPage(product: p)));

      expect(find.byType(Image), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Hero && w.tag == productHeroTag(p)),
        findsOneWidget,
      );
    });
  });

  group('dialog admin', () {
    Future<void> pumpAdmin(WidgetTester tester) async {
      size(tester, 600, 2400);
      await tester.pumpWidget(app(const AdminProductsPage()));
    }

    Future<void> openEdit(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Edit').first);
      await tester.pumpAndSettle();
    }

    Finder preview() => find.byKey(const ValueKey('photo-preview'));

    testWidgets('tanpa foto: tombol Pilih Foto dan tidak ada Hapus Foto', (
      tester,
    ) async {
      await pumpAdmin(tester);
      await openEdit(tester);

      expect(find.text('Pilih Foto'), findsOneWidget);
      expect(find.text('Hapus Foto'), findsNothing);
    });

    testWidgets('memilih foto menampilkan pratinjau, simpan menyimpan jalur', (
      tester,
    ) async {
      final photo = newPhoto();
      fake.toPick.add(photo);
      await pumpAdmin(tester);
      await openEdit(tester);

      await tester.tap(find.text('Pilih Foto'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: preview(), matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(find.text('Ganti Foto'), findsOneWidget);

      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(store.products[0].imagePath, photo);
      expect(fake.deleted, isEmpty);
    });

    testWidgets(
      'memilih lalu Batal: foto sementara dihapus, data tak berubah',
      (tester) async {
        final photo = newPhoto();
        fake.toPick.add(photo);
        await pumpAdmin(tester);
        await openEdit(tester);
        await tester.tap(find.text('Pilih Foto'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        expect(store.products[0].imagePath, isNull);
        expect(fake.deleted, [photo]);
      },
    );

    testWidgets('mengganti foto: foto lama dan foto yang dibatalkan dihapus', (
      tester,
    ) async {
      final old = newPhoto();
      final first = newPhoto();
      final second = newPhoto();
      store.products[0].imagePath = old;
      fake.toPick.addAll([first, second]);
      await pumpAdmin(tester);
      await openEdit(tester);

      await tester.tap(find.text('Ganti Foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ganti Foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(store.products[0].imagePath, second);
      expect(fake.deleted, containsAll([old, first]));
      expect(fake.deleted, isNot(contains(second)));
    });

    testWidgets('Hapus Foto lalu simpan mengosongkan dan menghapus file', (
      tester,
    ) async {
      final old = newPhoto();
      store.products[0].imagePath = old;
      await pumpAdmin(tester);
      await openEdit(tester);
      expect(find.text('Hapus Foto'), findsOneWidget);

      await tester.tap(find.text('Hapus Foto'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Foto'), findsNothing);
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(store.products[0].imagePath, isNull);
      expect(fake.deleted, [old]);
    });

    testWidgets('pilih galeri dibatalkan: tidak ada perubahan', (tester) async {
      await pumpAdmin(tester);
      await openEdit(tester);

      await tester.tap(find.text('Pilih Foto')); // fake: tidak ada foto
      await tester.pumpAndSettle();

      expect(find.text('Pilih Foto'), findsOneWidget);
      expect(fake.deleted, isEmpty);
    });

    testWidgets('produk baru dengan foto', (tester) async {
      final photo = newPhoto();
      fake.toPick.add(photo);
      await pumpAdmin(tester);
      await tester.tap(find.text('Tambah Produk'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pilih Foto'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nama Produk'),
        'Rantai',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Harga'), '90000');
      await tester.enterText(find.widgetWithText(TextField, 'Stok'), '5');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      final added = store.products.last;
      expect(added.name, 'Rantai');
      expect(added.imagePath, photo);
    });

    testWidgets('menghapus produk ikut menghapus file fotonya', (tester) async {
      final photo = newPhoto();
      store.products[0].imagePath = photo;
      final before = store.products.length;
      await pumpAdmin(tester);

      await tester.tap(find.byTooltip('Hapus').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();

      expect(store.products.length, before - 1);
      expect(fake.deleted, [photo]);
    });
  });
}
