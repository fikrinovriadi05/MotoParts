import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:motopart/models/cart_item.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Store extends ChangeNotifier {
  static const storageKey = 'motopart_state_v1';

  SharedPreferences? _prefs;

  /// Menghubungkan [Store] ke penyimpanan lokal: memuat data tersimpan (jika
  /// ada), lalu menyimpan otomatis setiap kali data berubah.
  /// Tanpa memanggil ini, [Store] hanya bekerja di memori (dipakai di tes).
  Future<void> attach(SharedPreferences prefs) async {
    _prefs = prefs;
    final raw = prefs.getString(storageKey);
    if (raw == null) return;
    try {
      _restore(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Data rusak/tidak cocok: abaikan dan pakai data bawaan.
    }
    super.notifyListeners();
  }

  void _restore(Map<String, dynamic> data) {
    final loadedProducts = (data['products'] as List)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
    final loadedOrders = (data['orders'] as List)
        .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final loadedCart = <CartItem>[];
    for (final e in data['cart'] as List) {
      final map = e as Map<String, dynamic>;
      final index = loadedProducts.indexWhere((p) => p.id == map['productId']);
      if (index < 0) continue;
      final product = loadedProducts[index];
      final qty = (map['qty'] as int).clamp(0, product.stock);
      if (qty > 0) loadedCart.add(CartItem(product: product, qty: qty));
    }

    products
      ..clear()
      ..addAll(loadedProducts);
    orders
      ..clear()
      ..addAll(loadedOrders);
    cart
      ..clear()
      ..addAll(loadedCart);
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    final data = {
      'products': products.map((e) => e.toJson()).toList(),
      'cart': cart
          .map((e) => {'productId': e.product.id, 'qty': e.qty})
          .toList(),
      'orders': orders.map((e) => e.toJson()).toList(),
    };
    prefs.setString(storageKey, jsonEncode(data));
  }

  @override
  void notifyListeners() {
    _save();
    super.notifyListeners();
  }

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

  /// Jumlah produk [product] yang sudah ada di keranjang.
  int qtyInCart(Product product) {
    final index = cart.indexWhere((e) => e.product.id == product.id);
    return index >= 0 ? cart[index].qty : 0;
  }

  /// Menambah produk ke keranjang. Mengembalikan `false` (dan tidak mengubah
  /// apa pun) jika jumlah di keranjang sudah mencapai stok.
  bool addToCart(Product product) {
    if (qtyInCart(product) >= product.stock) return false;

    final index = cart.indexWhere((e) => e.product.id == product.id);
    if (index >= 0) {
      cart[index].qty++;
    } else {
      cart.add(CartItem(product: product));
    }
    notifyListeners();
    return true;
  }

  /// Menaikkan qty item di keranjang. Mengembalikan `false` jika produk tidak
  /// ada di keranjang atau qty sudah mencapai stok.
  bool increaseQty(Product product) {
    final index = cart.indexWhere((e) => e.product.id == product.id);
    if (index < 0 || cart[index].qty >= product.stock) return false;

    cart[index].qty++;
    notifyListeners();
    return true;
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

  /// Mengubah data produk. Hanya argumen yang diisi yang diubah. Keranjang
  /// ikut disesuaikan: qty dipangkas ke stok baru, dan item dikeluarkan jika
  /// stok menjadi 0.
  void updateProduct(
    Product product, {
    String? name,
    String? category,
    String? type,
    int? price,
    int? stock,
    String? description,
  }) {
    if (name != null) product.name = name;
    if (category != null) product.category = category;
    if (type != null) product.type = type;
    if (price != null) product.price = price;
    if (stock != null) product.stock = stock < 0 ? 0 : stock;
    if (description != null) product.description = description;

    for (final item in cart) {
      if (item.product.id == product.id && item.qty > product.stock) {
        item.qty = product.stock;
      }
    }
    cart.removeWhere((item) => item.qty <= 0);
    notifyListeners();
  }

  void deleteProduct(Product product) {
    products.removeWhere((e) => e.id == product.id);
    notifyListeners();
  }

  static const orderStatuses = [
    'Diproses',
    'Dikemas',
    'Dikirim',
    'Selesai',
    'Dibatalkan',
  ];

  /// Pesanan yang cocok dengan [query] (kode atau nama pelanggan, tanpa
  /// membedakan huruf besar/kecil) dan [status] (null = semua status).
  List<OrderItem> filterOrders({String query = '', String? status}) {
    final q = query.trim().toLowerCase();
    return orders.where((o) {
      if (status != null && o.status != status) return false;
      if (q.isEmpty) return true;
      return o.code.toLowerCase().contains(q) ||
          o.customer.toLowerCase().contains(q);
    }).toList();
  }

  static const cancelledStatus = 'Dibatalkan';

  /// Mengubah status pesanan. Stok dikembalikan saat pesanan menjadi
  /// "Dibatalkan", dan dikurangi lagi jika pesanan diaktifkan kembali.
  /// Produk yang sudah dihapus dilewati.
  void updateOrderStatus(OrderItem order, String status) {
    final wasCancelled = order.status == cancelledStatus;
    final isCancelled = status == cancelledStatus;
    order.status = status;

    if (wasCancelled != isCancelled) {
      final direction = isCancelled ? 1 : -1;
      for (final line in order.lines) {
        final index = products.indexWhere((p) => p.id == line.productId);
        if (index < 0) continue;
        final product = products[index];
        product.stock = (product.stock + direction * line.qty).clamp(
          0,
          1 << 30,
        );
      }
    }
    notifyListeners();
  }

  void checkout({
    required String customer,
    required int shippingCost,
    DateTime? now,
  }) {
    final createdAt = now ?? DateTime.now();
    final orderCode = 'MP-${createdAt.millisecondsSinceEpoch}';
    for (final item in cart) {
      item.product.stock = (item.product.stock - item.qty).clamp(0, 1 << 30);
    }
    orders.insert(
      0,
      OrderItem(
        code: orderCode,
        customer: customer,
        total: cartTotal + shippingCost,
        status: 'Diproses',
        createdAt: createdAt,
        lines: [
          for (final item in cart)
            OrderLine(
              productId: item.product.id,
              name: item.product.name,
              qty: item.qty,
              price: item.product.price,
            ),
        ],
      ),
    );
    clearCart();
  }
}

final Store store = Store();
