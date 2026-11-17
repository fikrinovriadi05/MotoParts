import 'package:flutter/material.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/store.dart';

/// Lama notifikasi "Ditambahkan ke keranjang" tampil.
const snackDuration = Duration(seconds: 3);

/// Pindah ke tab Keranjang di halaman pembeli dari mana pun.
void goToCartTab(NavigatorState navigator) {
  userTabIndex.value = UserTab.cart;
  navigator.popUntil((route) => route.isFirst);
}

/// Menambah [qty] unit [product] ke keranjang lalu menampilkan SnackBar
/// ("Ditambahkan ke keranjang" + tombol "Lihat"). Mengembalikan jumlah unit
/// yang benar-benar masuk (bisa kurang dari [qty] jika stok terbatas).
int addToCartWithFeedback(
  BuildContext context,
  Product product, {
  int qty = 1,
}) {
  var added = 0;
  for (var i = 0; i < qty; i++) {
    if (!store.addToCart(product)) break;
    added++;
  }

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  messenger.hideCurrentSnackBar();

  if (added == 0) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Stok ${product.name} hanya ${product.stock} unit.'),
      ),
    );
    return 0;
  }

  final partial = added < qty ? ' ($added unit, sesuai stok)' : '';
  messenger.showSnackBar(
    SnackBar(
      content: Text('Ditambahkan ke keranjang$partial'),
      // Snackbar ber-aksi tidak hilang sendiri secara bawaan dan akan menutupi
      // tombol di bawahnya (mis. Checkout); paksa tertutup otomatis.
      persist: false,
      duration: snackDuration,
      action: SnackBarAction(
        label: 'Lihat',
        onPressed: () => goToCartTab(navigator),
      ),
    ),
  );
  return added;
}
