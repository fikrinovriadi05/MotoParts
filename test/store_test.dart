import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/store.dart';

void main() {
  late Store store;

  setUp(() {
    store = Store();
  });

  group('formatRupiah', () {
    test('memberi titik pemisah ribuan', () {
      expect(formatRupiah(0), 'Rp0');
      expect(formatRupiah(999), 'Rp999');
      expect(formatRupiah(45000), 'Rp45.000');
      expect(formatRupiah(1250000), 'Rp1.250.000');
    });
  });

  group('keranjang', () {
    test('awalnya kosong', () {
      expect(store.cart, isEmpty);
      expect(store.cartCount, 0);
      expect(store.cartTotal, 0);
    });

    test('addToCart menambah item baru dengan qty 1', () {
      store.addToCart(store.products[0]);

      expect(store.cart.length, 1);
      expect(store.cart.first.qty, 1);
      expect(store.cartCount, 1);
    });

    test(
      'addToCart pada produk yang sama menaikkan qty, bukan menambah baris',
      () {
        final product = store.products[0];
        store.addToCart(product);
        store.addToCart(product);

        expect(store.cart.length, 1);
        expect(store.cart.first.qty, 2);
      },
    );

    test('cartCount dan cartTotal menghitung semua item', () {
      final a = store.products[0]; // 45.000
      final b = store.products[1]; // 25.000
      store.addToCart(a);
      store.addToCart(a);
      store.addToCart(b);

      expect(store.cartCount, 3);
      expect(store.cartTotal, 45000 * 2 + 25000);
    });

    test('increaseQty menaikkan qty', () {
      final product = store.products[0];
      store.addToCart(product);
      store.increaseQty(product);

      expect(store.cart.first.qty, 2);
    });

    test('decreaseQty menurunkan qty dan menghapus item saat qty 1', () {
      final product = store.products[0];
      store.addToCart(product);
      store.increaseQty(product);

      store.decreaseQty(product);
      expect(store.cart.first.qty, 1);

      store.decreaseQty(product);
      expect(store.cart, isEmpty);
    });

    test(
      'increaseQty dan decreaseQty pada produk di luar keranjang diabaikan',
      () {
        var notified = 0;
        store.addListener(() => notified++);

        store.increaseQty(store.products[0]);
        store.decreaseQty(store.products[0]);

        expect(store.cart, isEmpty);
        expect(notified, 0);
      },
    );

    test('removeCart menghapus seluruh qty satu produk', () {
      final a = store.products[0];
      final b = store.products[1];
      store.addToCart(a);
      store.addToCart(a);
      store.addToCart(b);

      store.removeCart(a);

      expect(store.cart.length, 1);
      expect(store.cart.first.product.id, b.id);
    });

    test('clearCart mengosongkan keranjang', () {
      store.addToCart(store.products[0]);
      store.addToCart(store.products[1]);

      store.clearCart();

      expect(store.cart, isEmpty);
      expect(store.cartCount, 0);
    });
  });

  group('stok', () {
    test('addToCart ditolak saat qty sudah sama dengan stok', () {
      final product = store.products[5]; // stok 8
      for (var i = 0; i < product.stock; i++) {
        expect(store.addToCart(product), isTrue);
      }

      expect(store.addToCart(product), isFalse);
      expect(store.qtyInCart(product), product.stock);
    });

    test('increaseQty ditolak saat qty sudah sama dengan stok', () {
      final product = store.products[5];
      store.addToCart(product);
      while (store.increaseQty(product)) {}

      expect(store.qtyInCart(product), product.stock);
      expect(store.increaseQty(product), isFalse);
    });

    test('produk dengan stok 0 tidak bisa dimasukkan ke keranjang', () {
      final product = store.products[0];
      product.stock = 0;

      expect(store.addToCart(product), isFalse);
      expect(store.cart, isEmpty);
    });

    test('penolakan tidak memanggil listener', () {
      final product = store.products[0];
      product.stock = 0;
      var notified = 0;
      store.addListener(() => notified++);

      store.addToCart(product);

      expect(notified, 0);
    });

    test('checkout mengurangi stok sesuai qty di keranjang', () {
      final a = store.products[0];
      final b = store.products[1];
      final stockA = a.stock;
      final stockB = b.stock;
      store.addToCart(a);
      store.addToCart(a);
      store.addToCart(b);

      store.checkout(customer: 'Siti', shippingCost: 10000);

      expect(a.stock, stockA - 2);
      expect(b.stock, stockB - 1);
    });
  });

  group('edit produk (admin)', () {
    test('updateProduct hanya mengubah field yang diisi', () {
      final product = store.products[0];
      final category = product.category;

      store.updateProduct(product, name: 'Kampas Baru', price: 50000);

      expect(product.name, 'Kampas Baru');
      expect(product.price, 50000);
      expect(product.category, category);
      expect(product.stock, 24);
    });

    test('cartTotal mengikuti harga baru', () {
      final product = store.products[0];
      store.addToCart(product);

      store.updateProduct(product, price: 60000);

      expect(store.cartTotal, 60000);
    });

    test('stok baru lebih kecil memangkas qty di keranjang', () {
      final product = store.products[0];
      for (var i = 0; i < 5; i++) {
        store.addToCart(product);
      }

      store.updateProduct(product, stock: 3);

      expect(store.qtyInCart(product), 3);
    });

    test('stok baru 0 mengeluarkan produk dari keranjang', () {
      final product = store.products[0];
      store.addToCart(product);

      store.updateProduct(product, stock: 0);

      expect(store.cart, isEmpty);
    });

    test('stok negatif dijadikan 0 dan listener dipanggil', () {
      var notified = 0;
      store.addListener(() => notified++);

      store.updateProduct(store.products[0], stock: -5);

      expect(store.products[0].stock, 0);
      expect(notified, 1);
    });
  });

  group('produk (admin)', () {
    Product newProduct(int id) => Product(
      id: id,
      name: 'Produk Tes',
      category: 'Mesin',
      type: 'Universal',
      price: 10000,
      stock: 5,
      icon: Icons.settings,
      description: 'Produk untuk pengujian.',
    );

    test('addProduct menambah produk ke daftar', () {
      final before = store.products.length;

      store.addProduct(newProduct(999));

      expect(store.products.length, before + 1);
      expect(store.products.last.id, 999);
    });

    test('deleteProduct menghapus produk berdasarkan id', () {
      final product = store.products[0];

      store.deleteProduct(product);

      expect(store.products.any((p) => p.id == product.id), isFalse);
    });
  });

  group('pesanan', () {
    test(
      'checkout membuat pesanan baru di urutan teratas dan menghitung total',
      () {
        store.addToCart(store.products[0]); // 45.000
        store.addToCart(store.products[1]); // 25.000
        final before = store.orders.length;

        store.checkout(customer: 'Siti', shippingCost: 10000);

        expect(store.orders.length, before + 1);
        final order = store.orders.first;
        expect(order.customer, 'Siti');
        expect(order.total, 45000 + 25000 + 10000);
        expect(order.status, 'Diproses');
        expect(order.code, startsWith('MP-'));
      },
    );

    test('checkout mengosongkan keranjang', () {
      store.addToCart(store.products[0]);

      store.checkout(customer: 'Siti', shippingCost: 10000);

      expect(store.cart, isEmpty);
      expect(store.cartTotal, 0);
    });

    test('updateOrderStatus mengubah status pesanan', () {
      final order = store.orders.first;

      store.updateOrderStatus(order, 'Dibatalkan');

      expect(store.orders.first.status, 'Dibatalkan');
    });
  });

  group('notifikasi perubahan', () {
    test('setiap perubahan data memanggil listener', () {
      var notified = 0;
      store.addListener(() => notified++);
      final product = store.products[0];

      store.addToCart(product); // 1
      store.increaseQty(product); // 2
      store.decreaseQty(product); // 3
      store.removeCart(product); // 4
      store.clearCart(); // 5
      store.deleteProduct(product); // 6
      store.updateOrderStatus(store.orders.first, 'Selesai'); // 7
      store.addToCart(store.products[0]); // 8
      store.checkout(customer: 'Siti', shippingCost: 0); // 9 (clearCart)

      expect(notified, 9);
    });

    test('checkout yang ditolak tidak memanggil listener', () {
      var notified = 0;
      store.addListener(() => notified++);

      expect(store.checkout(customer: 'Siti', shippingCost: 0), isFalse);

      expect(notified, 0);
    });
  });
}
