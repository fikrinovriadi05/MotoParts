import 'package:flutter/material.dart';
import 'package:motopart/models/cart_item.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/models/product.dart';

class Store extends ChangeNotifier {
  final List<Product> products = [
    Product(
      id: 1,
      name: 'Kampas Rem Depan',
      category: 'Rem',
      type: 'Honda Beat',
      price: 45000,
      stock: 24,
      icon: Icons.disc_full,
      description:
          'Kampas rem depan berkualitas tinggi untuk pengereman lebih optimal.',
    ),
    Product(
      id: 2,
      name: 'Filter Oli Honda',
      category: 'Mesin',
      type: 'Honda Vario',
      price: 25000,
      stock: 50,
      icon: Icons.filter_alt,
      description:
          'Filter oli original untuk menjaga performa mesin tetap bersih.',
    ),
    Product(
      id: 3,
      name: 'Busi NGK',
      category: 'Kelistrikan',
      type: 'Universal',
      price: 32000,
      stock: 40,
      icon: Icons.electric_bolt,
      description:
          'Busi motor untuk pembakaran lebih stabil dan performa lebih baik.',
    ),
    Product(
      id: 4,
      name: 'Oli Mesin 10W-40',
      category: 'Mesin',
      type: 'Berbagai tipe',
      price: 85000,
      stock: 30,
      icon: Icons.oil_barrel,
      description:
          'Oli mesin premium untuk menjaga ketahanan dan pelumasan mesin.',
    ),
    Product(
      id: 5,
      name: 'Lampu LED Motor',
      category: 'Kelistrikan',
      type: 'Universal',
      price: 65000,
      stock: 18,
      icon: Icons.lightbulb,
      description:
          'Lampu LED terang dan hemat daya untuk tampilan motor lebih modern.',
    ),
    Product(
      id: 6,
      name: 'Gear Set',
      category: 'Transmisi',
      type: 'Honda Supra X',
      price: 185000,
      stock: 8,
      icon: Icons.settings,
      description:
          'Gear set berkualitas untuk transmisi lebih halus dan tahan lama.',
    ),
  ];

  final List<CartItem> cart = [];

  final List<OrderItem> orders = [
    OrderItem(
      code: 'MP-250118-0001',
      customer: 'Budi Santoso',
      total: 80000,
      status: 'Selesai',
    ),
    OrderItem(
      code: 'MP-250118-0002',
      customer: 'Andi Pratama',
      total: 125000,
      status: 'Dikirim',
    ),
  ];

  int get cartCount => cart.fold(0, (sum, item) => sum + item.qty);

  int get cartTotal =>
      cart.fold(0, (sum, item) => sum + (item.product.price * item.qty));

  void addToCart(Product product) {
    final index = cart.indexWhere((e) => e.product.id == product.id);
    if (index >= 0) {
      cart[index].qty++;
    } else {
      cart.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void increaseQty(Product product) {
    final index = cart.indexWhere((e) => e.product.id == product.id);
    if (index >= 0) {
      cart[index].qty++;
      notifyListeners();
    }
  }

  void decreaseQty(Product product) {
    final index = cart.indexWhere((e) => e.product.id == product.id);
    if (index >= 0) {
      if (cart[index].qty > 1) {
        cart[index].qty--;
      } else {
        cart.removeAt(index);
      }
      notifyListeners();
    }
  }

  void removeCart(Product product) {
    cart.removeWhere((e) => e.product.id == product.id);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  void addProduct(Product product) {
    products.add(product);
    notifyListeners();
  }

  void deleteProduct(Product product) {
    products.removeWhere((e) => e.id == product.id);
    notifyListeners();
  }

  void updateOrderStatus(OrderItem order, String status) {
    order.status = status;
    notifyListeners();
  }

  void checkout({
    required String customer,
    required int shippingCost,
  }) {
    final orderCode = 'MP-${DateTime.now().millisecondsSinceEpoch}';
    orders.insert(
      0,
      OrderItem(
        code: orderCode,
        customer: customer,
        total: cartTotal + shippingCost,
        status: 'Diproses',
      ),
    );
    clearCart();
  }
}

final Store store = Store();
