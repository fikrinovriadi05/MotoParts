import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/pages/user/catalog_page.dart';
import 'package:motopart/store/store.dart';

void main() {
  group('Store.searchProducts', () {
    late Store s;
    setUp(() => s = Store());

    List<String> names(List<dynamic> products) =>
        products.map((p) => p.name as String).toList();

    test('tanpa filter mengembalikan semua produk dengan urutan bawaan', () {
      final result = s.searchProducts();

      expect(names(result), names(s.products));
    });

    test('filter kategori; "Semua" berarti tanpa filter', () {
      expect(
        s.searchProducts(category: 'Mesin').every((p) => p.category == 'Mesin'),
        isTrue,
      );
      expect(s.searchProducts(category: 'Semua').length, s.products.length);
    });

    test('kata kunci tidak membedakan huruf besar/kecil', () {
      expect(names(s.searchProducts(keyword: 'bUsI')), ['Busi NGK']);
    });

    test('harga minimum dan maksimum bersifat inklusif', () {
      final result = s.searchProducts(minPrice: 32000, maxPrice: 65000);

      expect(names(result), [
        'Kampas Rem Depan', // 45.000
        'Busi NGK', // 32.000
        'Lampu LED Motor', // 65.000
      ]);
    });

    test('hanya harga minimum', () {
      final result = s.searchProducts(minPrice: 100000);

      expect(names(result), ['Gear Set']);
    });

    test('hanya harga maksimum', () {
      final result = s.searchProducts(maxPrice: 25000);

      expect(names(result), ['Filter Oli Honda']);
    });

    test('urut harga terendah dan tertinggi', () {
      final low = s.searchProducts(sort: ProductSort.priceLowToHigh);
      final high = s.searchProducts(sort: ProductSort.priceHighToLow);

      expect(low.first.price, 25000);
      expect(low.last.price, 185000);
      expect(high.first.price, 185000);
      expect(high.last.price, 25000);
    });

    test('urut nama A-Z', () {
      final result = names(s.searchProducts(sort: ProductSort.nameAZ));

      expect(result, [...result]..sort((a, b) => a.compareTo(b)));
      expect(result.first, 'Busi NGK');
    });

    test('semua filter digabung', () {
      final result = s.searchProducts(
        category: 'Mesin',
        maxPrice: 50000,
        sort: ProductSort.priceHighToLow,
      );

      expect(names(result), ['Filter Oli Honda']);
    });

    test('rentang yang tidak cocok menghasilkan daftar kosong', () {
      expect(s.searchProducts(minPrice: 1000000), isEmpty);
    });
  });

  group('CatalogPage', () {
    setUp(() {
      final fresh = Store();
      store.products
        ..clear()
        ..addAll(fresh.products);
    });

    Future<void> openSheet(WidgetTester tester) async {
      // Layar tinggi supaya semua produk di GridView ikut terbangun.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: CatalogPage()));
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
    }

    testWidgets('filter harga menyaring produk di katalog', (tester) async {
      await openSheet(tester);
      expect(find.text('Gear Set'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Harga minimum'),
        '100000',
      );
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      expect(find.text('Gear Set'), findsOneWidget);
      expect(find.text('Busi NGK'), findsNothing);
    });

    testWidgets('rentang terbalik menampilkan pesan dan sheet tetap terbuka', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Harga minimum'),
        '90000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Harga maksimum'),
        '10000',
      );
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('minimum tidak boleh lebih besar'),
        findsOneWidget,
      );
      expect(find.text('Terapkan'), findsOneWidget);
    });

    testWidgets('tidak ada hasil menampilkan pesan, Reset mengembalikan', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Harga minimum'),
        '9000000',
      );
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada produk yang cocok.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada produk yang cocok.'), findsNothing);
      expect(find.text('Gear Set'), findsOneWidget);
    });
  });
}
