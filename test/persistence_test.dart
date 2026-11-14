import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Store> _newStore([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final store = Store();
  await store.attach(await SharedPreferences.getInstance());
  return store;
}

/// Membuat Store baru yang memuat data yang disimpan [previous].
Future<Store> _reload(Store previous) async {
  final prefs = await SharedPreferences.getInstance();
  final reloaded = Store();
  await reloaded.attach(prefs);
  return reloaded;
}

void main() {
  test('tanpa data tersimpan, Store memakai data bawaan', () async {
    final store = await _newStore();

    expect(store.products.length, 6);
    expect(store.cart, isEmpty);
    expect(store.orders.length, 2);
  });

  test('keranjang tersimpan dan dimuat kembali', () async {
    final store = await _newStore();
    store.addToCart(store.products[0]);
    store.addToCart(store.products[0]);
    store.addToCart(store.products[1]);

    final reloaded = await _reload(store);

    expect(reloaded.cartCount, 3);
    expect(reloaded.cartTotal, store.cartTotal);
  });

  test('checkout menyimpan pesanan baru dan stok yang berkurang', () async {
    final store = await _newStore();
    final stock = store.products[0].stock;
    store.addToCart(store.products[0]);
    store.checkout(customer: 'Siti', shippingCost: 10000);

    final reloaded = await _reload(store);

    expect(reloaded.orders.first.customer, 'Siti');
    expect(reloaded.orders.first.total, 55000);
    expect(reloaded.orders.length, 3);
    expect(reloaded.products[0].stock, stock - 1);
    expect(reloaded.cart, isEmpty);
  });

  test('produk tambahan dan penghapusan produk tersimpan', () async {
    final store = await _newStore();
    store.deleteProduct(store.products[0]);
    store.addProduct(
      Product(
        id: 99,
        name: 'Produk Baru',
        category: 'Mesin',
        type: 'Universal',
        price: 12345,
        stock: 7,
        icon: Icons.build,
        description: 'Deskripsi',
      ),
    );

    final reloaded = await _reload(store);

    expect(reloaded.products.any((p) => p.id == 1), isFalse);
    final added = reloaded.products.firstWhere((p) => p.id == 99);
    expect(added.name, 'Produk Baru');
    expect(added.price, 12345);
    expect(added.stock, 7);
    expect(added.icon, Icons.build);
  });

  test('perubahan status pesanan tersimpan', () async {
    final store = await _newStore();
    store.updateOrderStatus(store.orders.first, 'Dibatalkan');

    final reloaded = await _reload(store);

    expect(reloaded.orders.first.status, 'Dibatalkan');
  });

  test('qty di keranjang dibatasi stok saat dimuat', () async {
    final store = await _newStore();
    final raw =
        jsonDecode(store.products.isEmpty ? '{}' : _snapshot(store)) as Map;
    (raw['cart'] as List).add({'productId': 6, 'qty': 999});
    SharedPreferences.setMockInitialValues({Store.storageKey: jsonEncode(raw)});

    final reloaded = Store();
    await reloaded.attach(await SharedPreferences.getInstance());

    expect(
      reloaded.qtyInCart(reloaded.products.firstWhere((p) => p.id == 6)),
      8,
    ); // stok Gear Set = 8
  });

  test('data rusak diabaikan dan memakai data bawaan', () async {
    final store = await _newStore({Store.storageKey: 'bukan json'});

    expect(store.products.length, 6);
    expect(store.orders.length, 2);
  });
}

String _snapshot(Store store) {
  return jsonEncode({
    'products': store.products.map((e) => e.toJson()).toList(),
    'cart': <Object>[],
    'orders': store.orders.map((e) => e.toJson()).toList(),
  });
}
