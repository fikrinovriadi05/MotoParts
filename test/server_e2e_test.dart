// Tes ujung ke ujung: aplikasi (Store/AuthStore) melawan server PHP + MySQL
// sungguhan. Dilewati kecuali MOTOPART_E2E_URL diatur; dijalankan oleh
// backend/tests/run.ps1 -E2E terhadap database UJI (data contoh direset!).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/remote_gateway.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/remote_sync.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final url = Platform.environment['MOTOPART_E2E_URL'];

  test(
    'alur lengkap pembeli dan admin melawan database',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = HttpRemoteGateway(url!);
      remoteGateway = gateway;
      addTearDown(() => remoteGateway = null);
      await store.attach(prefs);
      await auth.attach(prefs);

      // --- Admin masuk, mereset data contoh.
      expect(
        await auth.loginAsync(
          email: AuthStore.adminEmail,
          password: AuthStore.adminInitialPassword,
          role: AccountRole.admin,
        ),
        isNull,
      );
      expect(auth.isAdmin, isTrue);
      expect(auth.adminUsesDefaultPassword, isTrue);
      store.resetSampleData();
      await RemoteSync.settled;
      expect(store.products, hasLength(12));
      expect(store.orders, hasLength(2));
      expect(store.orders.first.createdAt, isNotNull);

      // Admin menambah produk (id dari database).
      expect(
        await store.createProduct(
          name: 'Kampas Uji E2E',
          category: 'Rem',
          type: 'Matic',
          price: 50000,
          stock: 4,
          description: 'Dibuat oleh tes',
        ),
        isNull,
      );
      final kampas = store.products.firstWhere(
        (p) => p.name == 'Kampas Uji E2E',
      );
      expect(kampas.id, greaterThan(12));
      // Kategori: tambah, ubah nama (produk ikut pindah), lalu hapus.
      Product kampasNow() =>
          store.products.firstWhere((p) => p.id == kampas.id);
      expect(store.addCategory('Aki', 'electric_bolt'), isNull);
      await RemoteSync.settled;
      expect(store.categoryNames, contains('Aki'));
      store.updateProduct(kampasNow(), category: 'Aki');
      await RemoteSync.settled;
      final aki = store.categories.firstWhere((c) => c.name == 'Aki');
      expect(
        store.updateCategory(aki, name: 'Aki Motor', iconKey: 'speed'),
        isNull,
      );
      await RemoteSync.settled;
      expect(store.categoryNames, contains('Aki Motor'));
      expect(store.categoryNames, isNot(contains('Aki')));
      expect(
        store.categories.firstWhere((c) => c.name == 'Aki Motor').iconKey,
        'speed',
      );
      expect(kampasNow().category, 'Aki Motor');
      store.updateProduct(kampasNow(), category: 'Rem');
      await RemoteSync.settled;
      expect(
        store.deleteCategory(
          store.categories.firstWhere((c) => c.name == 'Aki Motor'),
        ),
        isNull,
      );
      await RemoteSync.settled;
      expect(store.categoryNames, isNot(contains('Aki Motor')));
      auth.logout();

      // --- Pembeli: daftar, masuk, lengkapi profil dan alamat.
      final email = 'e2e${DateTime.now().millisecondsSinceEpoch}@mail.com';
      expect(
        await auth.registerAsync(
          name: 'Penguji E2E',
          email: email,
          phone: '081234567890',
          password: 'rahasia1',
        ),
        isNull,
      );
      expect(
        await auth.registerAsync(
          name: 'Penguji E2E',
          email: email,
          phone: '081234567890',
          password: 'rahasia1',
        ),
        'Email sudah terdaftar.',
      );
      expect(
        await auth.loginAsync(
          email: email,
          password: 'salah-salah',
          role: AccountRole.user,
        ),
        'Email atau password salah.',
      );
      expect(
        await auth.loginAsync(
          email: email,
          password: 'rahasia1',
          role: AccountRole.user,
        ),
        isNull,
      );
      final userId = auth.currentAccount!.id;
      expect(store.currentAccountId, userId);

      expect(
        auth.updateProfile(
          name: 'Penguji E2E',
          phone: '081234567890',
          motorName: 'Honda Vario',
          motorType: 'Matic',
          motorYear: '2021',
        ),
        isNull,
      );
      String? addressId;
      expect(
        auth.addAddress(
          label: 'Rumah',
          recipient: 'Penguji',
          phone: '081234567890',
          street: 'Jl. Merdeka 1',
          city: 'Pekanbaru',
          postalCode: '28111',
          latitude: 0.5071,
          longitude: 101.4478,
          onSaved: (a) => addressId = a.id,
        ),
        isNull,
      );
      expect(auth.setPreferredPayment('QRIS'), isNull);
      await RemoteSync.settled;

      // Data kembali utuh dari database (bukan hanya tampilan optimis).
      await RemoteSync.pull();
      final me = auth.currentAccount!;
      expect(me.motorName, 'Honda Vario');
      expect(me.motorYear, 2021);
      expect(me.addresses.single.id, addressId);
      expect(me.addresses.single.latitude, closeTo(0.5071, 1e-6));
      expect(me.defaultAddressId, addressId);
      expect(me.preferredPayment, 'QRIS');
      expect(me.passwordHash, isEmpty);

      // --- Belanja: checkout memotong stok di database.
      final busi = store.products.firstWhere((p) => p.id == kampas.id);
      store.addToCart(busi);
      store.addToCart(busi);
      final failed = await store.placeOrder(
        customer: 'Penguji E2E',
        shippingCost: 10000,
        address: 'Penguji, Jl. Merdeka 1',
        paymentMethod: 'COD',
      );
      expect(failed, isNull);
      expect(store.cart, isEmpty);
      final order = store.ordersForCurrentAccount.single;
      expect(order.total, 2 * 50000 + 10000);
      expect(order.status, 'Diproses');
      expect(order.accountId, userId);
      expect(store.products.firstWhere((p) => p.id == kampas.id).stock, 2);

      // Stok tidak cukup ditolak server.
      store.addToCart(busi);
      store.addToCart(busi);
      store.addToCart(busi);
      store.cart.single.qty = 3; // melewati batas stok lokal
      final tooMany = await store.placeOrder(
        customer: 'Penguji E2E',
        shippingCost: 0,
      );
      expect(tooMany, isNotNull);
      expect(tooMany!.single, contains('tinggal 2'));
      store.clearCart();

      // Ulasan sebelum pesanan selesai ditolak (aturan juga di aplikasi).
      expect(store.canReview(busi), isFalse);
      auth.logout();

      // --- Admin menyelesaikan pesanan.
      await auth.loginAsync(
        email: AuthStore.adminEmail,
        password: AuthStore.adminInitialPassword,
        role: AccountRole.admin,
      );
      expect(store.orderByCode(order.code), isNotNull);
      expect(auth.userAccounts.any((a) => a.email == email), isTrue);
      store.updateOrderStatus(store.orderByCode(order.code)!, 'Selesai');
      await RemoteSync.settled;
      expect(store.orderByCode(order.code)!.status, 'Selesai');
      auth.logout();

      // --- Pembeli: ulasan dan wishlist.
      await auth.loginAsync(
        email: email,
        password: 'rahasia1',
        role: AccountRole.user,
      );
      final bought = store.products.firstWhere((p) => p.id == kampas.id);
      expect(store.canReview(bought), isTrue);
      expect(
        store.submitReview(
          bought,
          rating: 5,
          comment: 'Mantap',
          authorName: auth.currentAccount!.name,
        ),
        isNull,
      );
      store.toggleWishlist(bought);
      await RemoteSync.settled;

      // Perangkat lain (sesi baru dengan token yang sama) melihat data yang sama.
      store.reviews.clear();
      store.wishlistIds.clear();
      await RemoteSync.pull();
      expect(store.reviewsFor(bought).single.rating, 5);
      expect(store.isWishlisted(bought), isTrue);

      // --- Ganti password lewat server.
      expect(
        await auth.changePasswordAsync(
          oldPassword: 'rahasia1',
          newPassword: 'baru-baru-1',
        ),
        isNull,
      );
      auth.logout();
      expect(
        await auth.loginAsync(
          email: email,
          password: 'rahasia1',
          role: AccountRole.user,
        ),
        'Email atau password salah.',
      );
      expect(
        await auth.loginAsync(
          email: email,
          password: 'baru-baru-1',
          role: AccountRole.user,
        ),
        isNull,
      );
      auth.logout();

      // --- Sesi dipulihkan dari token setelah "aplikasi dibuka ulang".
      await auth.loginAsync(
        email: email,
        password: 'baru-baru-1',
        role: AccountRole.user,
      );
      final saved = prefs.getString(AuthStore.tokenKey)!;
      gateway.token = null;
      auth.sessionExpired(); // meniru proses baru tanpa sesi di memori
      gateway.token = saved;
      await RemoteSync.bootstrap();
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentAccount!.email, email);

      // Bersihkan: kembalikan data contoh.
      auth.logout();
      await auth.loginAsync(
        email: AuthStore.adminEmail,
        password: AuthStore.adminInitialPassword,
        role: AccountRole.admin,
      );
      store.resetSampleData();
      await RemoteSync.settled;
    },
    skip: url == null || url.isEmpty
        ? 'Atur MOTOPART_E2E_URL (lihat backend/tests/run.ps1 -E2E)'
        : false,
  );
}
