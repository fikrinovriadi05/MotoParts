import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Store store;
  setUp(() => store = Store());

  /// Checkout 2x produk[0] dan 1x produk[1]; mengembalikan pesanannya.
  dynamic placeOrder() {
    store.addToCart(store.products[0]);
    store.addToCart(store.products[0]);
    store.addToCart(store.products[1]);
    store.checkout(customer: 'Siti', shippingCost: 10000);
    return store.orders.first;
  }

  test('checkout mencatat barang yang dipesan', () {
    final order = placeOrder();

    expect(order.lines.length, 2);
    expect(order.lines[0].productId, store.products[0].id);
    expect(order.lines[0].qty, 2);
    expect(order.lines[0].price, 45000);
    expect(order.lines[1].qty, 1);
  });

  test('membatalkan pesanan mengembalikan stok', () {
    final stockA = store.products[0].stock;
    final stockB = store.products[1].stock;
    final order = placeOrder();
    expect(store.products[0].stock, stockA - 2);

    store.updateOrderStatus(order, 'Dibatalkan');

    expect(store.products[0].stock, stockA);
    expect(store.products[1].stock, stockB);
  });

  test('status lain selain Dibatalkan tidak mengubah stok', () {
    final order = placeOrder();
    final after = store.products[0].stock;

    store.updateOrderStatus(order, 'Dikemas');
    store.updateOrderStatus(order, 'Dikirim');
    store.updateOrderStatus(order, 'Selesai');

    expect(store.products[0].stock, after);
  });

  test('stok tidak dikembalikan dua kali jika dibatalkan berulang', () {
    final stockA = store.products[0].stock;
    final order = placeOrder();

    store.updateOrderStatus(order, 'Dibatalkan');
    store.updateOrderStatus(order, 'Dibatalkan');

    expect(store.products[0].stock, stockA);
  });

  test('mengaktifkan kembali pesanan batal mengurangi stok lagi', () {
    final stockA = store.products[0].stock;
    final order = placeOrder();
    store.updateOrderStatus(order, 'Dibatalkan');

    store.updateOrderStatus(order, 'Diproses');

    expect(store.products[0].stock, stockA - 2);
  });

  test('produk yang sudah dihapus dilewati tanpa error', () {
    final order = placeOrder();
    store.deleteProduct(store.products[0]);
    final stockB = store.products.first.stock;

    store.updateOrderStatus(order, 'Dibatalkan');

    expect(store.products.first.stock, stockB + 1);
  });

  test('membatalkan pesanan contoh mengembalikan stok barangnya', () {
    final kampas = store.products[0].stock;
    final filter = store.products[1].stock;
    final lain = store.products[2].stock;

    // Pesanan contoh pertama: 1 Filter Oli Honda + 1 Kampas Rem Depan.
    store.updateOrderStatus(store.orders.first, 'Dibatalkan');

    expect(store.products[0].stock, kampas + 1);
    expect(store.products[1].stock, filter + 1);
    expect(store.products[2].stock, lain);
  });

  test('pesanan lama tanpa daftar barang dibatalkan tanpa efek stok', () {
    final lama = OrderItem(
      code: 'MP-LAMA',
      customer: 'Lama',
      total: 50000,
      status: 'Diproses',
    );
    store.orders.add(lama);
    final before = store.products.map((p) => p.stock).toList();

    store.updateOrderStatus(lama, 'Dibatalkan');

    expect(store.products.map((p) => p.stock).toList(), before);
  });

  test('daftar barang pesanan tersimpan dan dimuat kembali', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final persisted = Store();
    await persisted.attach(prefs);
    persisted.addToCart(persisted.products[0]);
    persisted.checkout(customer: 'Siti', shippingCost: 0);

    final reloaded = Store();
    await reloaded.attach(prefs);

    expect(reloaded.orders.first.lines.single.qty, 1);
    expect(reloaded.orders.first.lines.single.name, 'Kampas Rem Depan');
  });
}
