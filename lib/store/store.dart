import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:motopart/models/cart_item.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/models/review.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ProductSort {
  standard('Urutan bawaan'),
  priceLowToHigh('Harga terendah'),
  priceHighToLow('Harga tertinggi'),
  nameAZ('Nama A-Z');

  final String label;
  const ProductSort(this.label);
}

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
    // Keranjang & wishlist disimpan per akun. Format lama (satu keranjang
    // untuk semua) tidak dibawa ke akun mana pun.
    final loadedCarts = <String, List<CartItem>>{};
    final cartsJson = (data['carts'] as Map?) ?? const {};
    for (final entry in cartsJson.entries) {
      final items = <CartItem>[];
      for (final e in entry.value as List) {
        final map = e as Map<String, dynamic>;
        final index = loadedProducts.indexWhere(
          (p) => p.id == map['productId'],
        );
        if (index < 0) continue;
        final product = loadedProducts[index];
        final qty = (map['qty'] as int).clamp(0, product.stock);
        if (qty > 0) items.add(CartItem(product: product, qty: qty));
      }
      loadedCarts[entry.key as String] = items;
    }

    final loadedWishlists = <String, Set<int>>{};
    final wishlistsJson = (data['wishlists'] as Map?) ?? const {};
    for (final entry in wishlistsJson.entries) {
      loadedWishlists[entry.key as String] = {
        for (final id in entry.value as List)
          if (id is int && loadedProducts.any((p) => p.id == id)) id,
      };
    }

    final loadedReviews = <Review>[
      for (final e in (data['reviews'] as List?) ?? const [])
        Review.fromJson(e as Map<String, dynamic>),
    ].where((r) => loadedProducts.any((p) => p.id == r.productId)).toList();

    products
      ..clear()
      ..addAll(loadedProducts);
    reviews
      ..clear()
      ..addAll(loadedReviews);
    orders
      ..clear()
      ..addAll(loadedOrders);
    _carts
      ..clear()
      ..addAll(loadedCarts);
    _wishlists
      ..clear()
      ..addAll(loadedWishlists);
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    final data = {
      'products': products.map((e) => e.toJson()).toList(),
      'carts': {
        for (final entry in _carts.entries)
          entry.key: entry.value
              .map((e) => {'productId': e.product.id, 'qty': e.qty})
              .toList(),
      },
      'orders': orders.map((e) => e.toJson()).toList(),
      'reviews': reviews.map((e) => e.toJson()).toList(),
      'wishlists': {
        for (final entry in _wishlists.entries) entry.key: entry.value.toList(),
      },
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
      icon: Icons.disc_full_rounded,
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
      icon: Icons.filter_alt_rounded,
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
      icon: Icons.electric_bolt_rounded,
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
      icon: Icons.oil_barrel_rounded,
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
      icon: Icons.lightbulb_rounded,
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
      icon: Icons.settings_rounded,
      description:
          'Gear set berkualitas untuk transmisi lebih halus dan tahan lama.',
    ),
  ];

  /// Id akun "tamu", dipakai selama belum ada yang login (dan di tes).
  static const guestId = 'guest';

  /// Akun yang sedang aktif. Keranjang, wishlist, dan riwayat pesanan pembeli
  /// mengikuti akun ini. Diatur oleh `AuthStore` lewat [setCurrentAccount].
  String currentAccountId = guestId;

  final Map<String, List<CartItem>> _carts = {};
  final Map<String, Set<int>> _wishlists = {};

  /// Keranjang akun yang sedang aktif.
  List<CartItem> get cart => _carts.putIfAbsent(currentAccountId, () => []);

  /// Id produk wishlist akun yang sedang aktif.
  Set<int> get wishlistIds =>
      _wishlists.putIfAbsent(currentAccountId, () => {});

  /// Berpindah ke akun [accountId] (null = tamu), mis. saat login/logout.
  void setCurrentAccount(String? accountId) {
    currentAccountId = accountId ?? guestId;
    notifyListeners();
  }

  /// Pesanan milik akun yang sedang aktif (untuk riwayat pembeli). Admin
  /// memakai [orders] untuk melihat semuanya.
  List<OrderItem> get ordersForCurrentAccount =>
      orders.where((o) => o.accountId == currentAccountId).toList();

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
    String? imagePath,
    bool clearImage = false,
  }) {
    if (name != null) product.name = name;
    if (category != null) product.category = category;
    if (type != null) product.type = type;
    if (price != null) product.price = price;
    if (stock != null) product.stock = stock < 0 ? 0 : stock;
    if (description != null) product.description = description;
    if (clearImage) {
      product.imagePath = null;
    } else if (imagePath != null) {
      product.imagePath = imagePath;
    }

    for (final items in _carts.values) {
      for (final item in items) {
        if (item.product.id == product.id && item.qty > product.stock) {
          item.qty = product.stock;
        }
      }
      items.removeWhere((item) => item.qty <= 0);
    }
    notifyListeners();
  }

  void deleteProduct(Product product) {
    products.removeWhere((e) => e.id == product.id);
    reviews.removeWhere((r) => r.productId == product.id);
    for (final items in _carts.values) {
      items.removeWhere((e) => e.product.id == product.id);
    }
    for (final ids in _wishlists.values) {
      ids.remove(product.id);
    }
    notifyListeners();
  }

  bool isWishlisted(Product product) => wishlistIds.contains(product.id);

  /// Produk wishlist, yang terakhir ditambahkan di paling atas.
  List<Product> get wishlistProducts => [
    for (final id in wishlistIds.toList().reversed)
      ...products.where((p) => p.id == id),
  ];

  /// Menambah/menghapus produk dari wishlist. Mengembalikan `true` jika
  /// sekarang produk ada di wishlist.
  bool toggleWishlist(Product product) {
    final added = wishlistIds.add(product.id);
    if (!added) wishlistIds.remove(product.id);
    notifyListeners();
    return added;
  }

  // ------------------------------------------------------------ ulasan

  static const maxCommentLength = 300;

  /// Semua ulasan, urutan = urutan dibuat.
  final List<Review> reviews = [];

  /// Ulasan satu produk, yang terbaru di atas.
  List<Review> reviewsFor(Product product) {
    final list = reviews.where((r) => r.productId == product.id).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Rata-rata rating produk, atau null jika belum ada ulasan.
  double? averageRating(Product product) {
    final list = reviews.where((r) => r.productId == product.id).toList();
    if (list.isEmpty) return null;
    return list.fold<int>(0, (sum, r) => sum + r.rating) / list.length;
  }

  /// Ulasan milik akun yang sedang aktif untuk [product], jika ada.
  Review? myReviewFor(Product product) {
    for (final r in reviews) {
      if (r.productId == product.id && r.accountId == currentAccountId) {
        return r;
      }
    }
    return null;
  }

  /// Hanya akun yang sudah login dan punya pesanan berstatus "Selesai" yang
  /// memuat produk ini yang boleh mengulas.
  bool canReview(Product product) {
    if (currentAccountId == guestId) return false;
    return orders.any(
      (o) =>
          o.accountId == currentAccountId &&
          o.status == 'Selesai' &&
          o.lines.any((l) => l.productId == product.id),
    );
  }

  /// Membuat atau mengganti ulasan akun aktif untuk [product]. Mengembalikan
  /// pesan kesalahan, atau `null` jika berhasil.
  String? submitReview(
    Product product, {
    required int rating,
    required String comment,
    required String authorName,
    DateTime? now,
  }) {
    if (!canReview(product)) {
      return 'Ulasan hanya untuk pembeli yang pesanannya sudah selesai.';
    }
    if (rating < 1 || rating > 5) return 'Pilih rating 1 sampai 5 bintang.';
    final text = comment.trim();
    if (text.length > maxCommentLength) {
      return 'Komentar maksimal $maxCommentLength karakter.';
    }

    reviews.removeWhere(
      (r) => r.productId == product.id && r.accountId == currentAccountId,
    );
    reviews.add(
      Review(
        productId: product.id,
        accountId: currentAccountId,
        authorName: authorName,
        rating: rating,
        comment: text,
        createdAt: now ?? DateTime.now(),
      ),
    );
    notifyListeners();
    return null;
  }

  /// Menghapus ulasan (dipakai admin untuk ulasan yang tidak pantas).
  void deleteReview(Review review) {
    reviews.remove(review);
    notifyListeners();
  }

  /// Jumlah unit terjual per id produk (pesanan yang dibatalkan tidak dihitung).
  Map<int, int> get unitsSold {
    final sold = <int, int>{};
    for (final order in orders) {
      if (order.status == cancelledStatus) continue;
      for (final line in order.lines) {
        sold[line.productId] = (sold[line.productId] ?? 0) + line.qty;
      }
    }
    return sold;
  }

  /// Pesanan yang dihitung sebagai penjualan (semua kecuali yang dibatalkan).
  List<OrderItem> get salesOrders =>
      orders.where((o) => o.status != cancelledStatus).toList();

  /// Total penjualan: jumlah total semua pesanan yang tidak dibatalkan.
  int get totalSales => salesOrders.fold(0, (sum, o) => sum + o.total);

  /// Total unit barang terjual (pesanan yang dibatalkan tidak dihitung).
  int get totalUnitsSold => unitsSold.values.fold(0, (sum, n) => sum + n);

  /// Penjualan per hari untuk 7 hari terakhir sampai [now] (hari terlama di
  /// depan). Pesanan tanpa tanggal tidak ikut dihitung per hari.
  List<({DateTime day, int total})> salesLast7Days(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = 6; i >= 0; i--)
        (
          day: DateTime(today.year, today.month, today.day - i),
          total: salesOrders
              .where((o) {
                final t = o.createdAt;
                return t != null &&
                    DateTime(t.year, t.month, t.day) ==
                        DateTime(today.year, today.month, today.day - i);
              })
              .fold(0, (sum, o) => sum + o.total),
        ),
    ];
  }

  /// Semua produk, yang paling banyak terjual di depan. Produk dengan jumlah
  /// terjual sama tetap berurutan seperti di daftar produk.
  List<Product> productsBySales() {
    final sold = unitsSold;
    final indexed = products.asMap().entries.toList();
    indexed.sort((a, b) {
      final diff = (sold[b.value.id] ?? 0).compareTo(sold[a.value.id] ?? 0);
      return diff != 0 ? diff : a.key.compareTo(b.key);
    });
    return [for (final e in indexed) e.value];
  }

  /// Mencari produk untuk katalog. [category] 'Semua'/null = semua kategori;
  /// [keyword] dicocokkan ke nama produk (tanpa membedakan huruf besar/kecil);
  /// [minPrice]/[maxPrice] membatasi harga (inklusif). [ProductSort.standard]
  /// mempertahankan urutan daftar produk.
  List<Product> searchProducts({
    String? category,
    String keyword = '',
    int? minPrice,
    int? maxPrice,
    ProductSort sort = ProductSort.standard,
  }) {
    final q = keyword.trim().toLowerCase();
    final result = products.where((p) {
      if (category != null && category != 'Semua' && p.category != category) {
        return false;
      }
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q)) return false;
      if (minPrice != null && p.price < minPrice) return false;
      if (maxPrice != null && p.price > maxPrice) return false;
      return true;
    }).toList();

    switch (sort) {
      case ProductSort.standard:
        break;
      case ProductSort.priceLowToHigh:
        result.sort((a, b) => a.price.compareTo(b.price));
      case ProductSort.priceHighToLow:
        result.sort((a, b) => b.price.compareTo(a.price));
      case ProductSort.nameAZ:
        result.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return result;
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

  /// Item keranjang yang jumlahnya melebihi stok saat ini, sebagai pesan siap
  /// tampil. Kosong jika semua item masih tersedia.
  List<String> get cartStockProblems => [
    for (final item in cart)
      if (item.qty > item.product.stock)
        item.product.stock <= 0
            ? '${item.product.name} sudah habis.'
            : 'Stok ${item.product.name} tinggal ${item.product.stock}.',
  ];

  /// Menyesuaikan keranjang dengan stok: qty dipangkas ke stok, item yang
  /// stoknya habis dikeluarkan.
  void trimCartToStock() {
    for (final item in cart) {
      if (item.qty > item.product.stock) item.qty = item.product.stock;
    }
    cart.removeWhere((item) => item.qty <= 0);
    notifyListeners();
  }

  /// Membuat pesanan dari keranjang akun aktif. Mengembalikan `false` (tanpa
  /// mengubah apa pun) jika keranjang kosong atau ada item yang melebihi
  /// stok, misalnya karena pembeli lain sudah membeli lebih dulu.
  bool checkout({
    required String customer,
    required int shippingCost,
    DateTime? now,
  }) {
    if (cart.isEmpty || cartStockProblems.isNotEmpty) return false;

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
        accountId: currentAccountId,
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
    return true;
  }
}

final Store store = Store();
