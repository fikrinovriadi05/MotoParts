import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/store/store.dart';

void main() {
  group('Store: Beli Sekarang', () {
    late Store s;

    setUp(() => s = Store());

    test('checkout hanya barang yang dibeli, keranjang tidak tersentuh', () {
      final inCart = s.products[0];
      final bought = s.products[1];
      inCart.stock = 5;
      bought.stock = 5;
      s.addToCart(inCart);

      s.startBuyNow(bought, 2);
      expect(s.checkoutItems.single.product, bought);
      expect(s.checkoutTotal, bought.price * 2);

      expect(s.checkout(customer: 'A', shippingCost: 1000), isTrue);

      final order = s.orders.first;
      expect(order.lines.single.productId, bought.id);
      expect(order.lines.single.qty, 2);
      expect(order.total, bought.price * 2 + 1000);
      expect(bought.stock, 3);
      expect(inCart.stock, 5, reason: 'barang di keranjang tidak ikut dibeli');
      expect(s.qtyInCart(inCart), 1, reason: 'keranjang tetap utuh');
      expect(s.checkoutItems, s.cart, reason: 'mode beli langsung selesai');
    });

    test('endBuyNow mengembalikan checkout ke isi keranjang', () {
      final inCart = s.products[0];
      inCart.stock = 5;
      s.addToCart(inCart);

      s.startBuyNow(s.products[1], 1);
      s.endBuyNow();

      expect(s.checkoutItems, s.cart);
      expect(s.checkoutTotal, s.cartTotal);
    });

    test('stok kurang: ditolak, lalu trim menyesuaikan jumlah', () {
      final p = s.products[0];
      p.stock = 3;
      s.startBuyNow(p, 5);

      expect(s.cartStockProblems, isNotEmpty);
      expect(s.checkout(customer: 'A', shippingCost: 0), isFalse);

      s.trimCartToStock();
      expect(s.checkoutItems.single.qty, 3);
      expect(s.checkout(customer: 'A', shippingCost: 0), isTrue);
      expect(p.stock, 0);
    });
  });
}
