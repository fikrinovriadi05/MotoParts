import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/categories.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/admin/admin_reports_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/product_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Store s;
  setUp(() => s = Store());

  group('produk contoh', () {
    test('ada 12 produk dengan id unik', () {
      expect(s.products.length, 12);
      expect(s.products.map((p) => p.id).toSet().length, 12);
    });

    test('setiap kategori punya minimal satu produk', () {
      for (final name in productCategoryNames) {
        expect(
          s.products.where((p) => p.category == name),
          isNotEmpty,
          reason: 'kategori $name kosong',
        );
      }
    });

    test('Oli, Ban, dan Body muncul di katalog', () {
      expect(s.searchProducts(category: 'Oli').length, greaterThanOrEqualTo(3));
      expect(s.searchProducts(category: 'Ban').length, 2);
      expect(s.searchProducts(category: 'Body').length, 2);
    });

    test('semua ikon produk terdaftar (tersimpan lewat nama)', () {
      for (final p in s.products) {
        expect(Product.icons.values, contains(p.icon), reason: p.name);
        final restored = Product.fromJson(p.toJson());
        expect(restored.icon, p.icon, reason: p.name);
      }
    });

    test('harga positif, stok tidak negatif, deskripsi terisi', () {
      for (final p in s.products) {
        expect(p.price, greaterThan(0), reason: p.name);
        expect(p.stock, greaterThanOrEqualTo(0), reason: p.name);
        expect(p.description.trim(), isNotEmpty, reason: p.name);
        expect(p.type.trim(), isNotEmpty, reason: p.name);
      }
    });

    test('ada contoh stok menipis (di bawah batas label merah)', () {
      expect(
        s.products.where(
          (p) => p.stock > 0 && p.stock < StockLabel.lowStockThreshold,
        ),
        isNotEmpty,
      );
    });

    test('merek motor produk multi-tipe terbaca sebagai chip terpisah', () {
      final matic = s.products.firstWhere((p) => p.id == 8);

      expect(matic.type.split(',').length, 3);
    });
  });

  group('pesanan contoh', () {
    test('punya rincian barang dan tanggal', () {
      for (final o in s.orders) {
        expect(o.lines, isNotEmpty, reason: o.code);
        expect(o.createdAt, isNotNull, reason: o.code);
        expect(o.accountId, isNull, reason: 'tanpa pemilik: hanya untuk admin');
      }
    });

    test('total = barang + ongkir Rp 10.000, harga & nama sesuai produk', () {
      for (final o in s.orders) {
        final items = o.lines.fold<int>(0, (sum, l) => sum + l.price * l.qty);
        expect(o.total, items + 10000, reason: o.code);

        for (final line in o.lines) {
          final product = s.products.firstWhere((p) => p.id == line.productId);
          expect(line.name, product.name, reason: o.code);
          expect(line.price, product.price, reason: o.code);
        }
      }
    });

    test('data penjualan contoh: 205.000, 5 unit', () {
      expect(s.totalSales, 205000);
      expect(s.totalUnitsSold, 5);
    });

    test('Produk Terlaris: Kampas (3 unit) lalu Filter Oli (2 unit)', () {
      final ranked = s.productsBySales();

      expect(ranked[0].name, 'Kampas Rem Depan');
      expect(ranked[1].name, 'Filter Oli Honda');
      expect(s.unitsSold[1], 3);
      expect(s.unitsSold[2], 2);
    });

    test('membatalkan pesanan contoh menghapusnya dari penjualan', () {
      s.updateOrderStatus(s.orders.first, 'Dibatalkan');

      expect(s.totalSales, 125000);
      expect(s.totalUnitsSold, 3);
    });
  });

  group('kompatibilitas data lama di perangkat', () {
    test(
      'data tersimpan dengan 6 produk & pesanan tanpa rincian tetap termuat',
      () async {
        // Bentuk data versi lama: 6 produk, pesanan tanpa lines/createdAt.
        final old = Store();
        final legacy = {
          'products': old.products.take(6).map((p) {
            final json = p.toJson()..remove('imagePath');
            return json;
          }).toList(),
          'carts': <String, Object>{},
          'wishlists': <String, Object>{},
          'orders': [
            {
              'code': 'MP-250118-0001',
              'customer': 'Budi Santoso',
              'total': 80000,
              'status': 'Selesai',
            },
          ],
        };
        SharedPreferences.setMockInitialValues({
          Store.storageKey: jsonEncode(legacy),
        });
        final loaded = Store();

        await loaded.attach(await SharedPreferences.getInstance());

        expect(loaded.products.length, 6);
        expect(loaded.orders.length, 1);
        expect(loaded.orders.single.lines, isEmpty);
        expect(loaded.orders.single.createdAt, isNull);
        // Pesanan lama tanpa rincian tetap bisa dibatalkan tanpa efek stok.
        final before = loaded.products.map((p) => p.stock).toList();
        loaded.updateOrderStatus(loaded.orders.single, 'Dibatalkan');
        expect(loaded.products.map((p) => p.stock).toList(), before);
      },
    );
  });

  group('laporan memakai data contoh', () {
    testWidgets('Barang Terjual tidak lagi 0', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fresh = Store();
      store.products
        ..clear()
        ..addAll(fresh.products);
      store.orders
        ..clear()
        ..addAll(fresh.orders);
      await tester.pumpWidget(
        MaterialApp(home: AdminReportsPage(now: DateTime(2026, 11, 16))),
      );

      expect(find.text('Barang Terjual'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });
  });
}
