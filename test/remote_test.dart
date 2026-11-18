import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motopart/core/remote_gateway.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/models/payment_info.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/remote_sync.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Handler = Map<String, dynamic> Function(
  String method,
  String path,
  Map<String, dynamic>? body,
);

/// Pengganti server: mencatat panggilan dan menjawab lewat [handler].
class FakeGateway extends RemoteGateway {
  final List<String> calls = [];
  final List<Map<String, dynamic>?> bodies = [];
  final List<String?> tokens = [];
  Handler handler;

  FakeGateway(this.handler);

  @override
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    calls.add('$method $path');
    bodies.add(body);
    tokens.add(token ?? this.token);
    return handler(method, path, body);
  }

  /// Panggilan selain `GET /sync` (yang dipanggil otomatis setelah perubahan).
  List<String> get writes => calls.where((c) => c != 'GET /sync').toList();
}

Map<String, dynamic> userJson({
  String id = 'u1',
  String role = 'user',
  List<Map<String, dynamic>> addresses = const [],
  String? defaultAddressId,
  bool usesDefaultPassword = false,
}) => {
  'id': id,
  'name': 'Budi Santoso',
  'email': 'budi@mail.com',
  'phone': '081234567890',
  'role': role,
  'motorName': '',
  'motorType': '',
  'motorYear': null,
  'addresses': addresses,
  'defaultAddressId': defaultAddressId,
  'preferredPayment': null,
  'usesDefaultPassword': usesDefaultPassword,
};

Map<String, dynamic> productJson(
  int id, {
  String name = 'Busi NGK',
  int price = 32000,
  int stock = 10,
}) => {
  'id': id,
  'name': name,
  'category': 'Kelistrikan',
  'type': 'Universal',
  'price': price,
  'stock': stock,
  'icon': 'build',
  'description': 'Deskripsi',
  'imagePath': null,
};

Map<String, dynamic> orderJson(
  String code, {
  String status = 'Diproses',
  String accountId = 'u1',
}) => {
  'code': code,
  'customer': 'Budi Santoso',
  'total': 42000,
  'status': status,
  'lines': [
    {'productId': 1, 'name': 'Busi NGK', 'qty': 1, 'price': 32000},
  ],
  'createdAt': '2026-11-17T05:30:00Z',
  'accountId': accountId,
  'address': null,
  'paymentMethod': 'COD',
  'payment': null,
};

Map<String, dynamic> snapshot({
  Map<String, dynamic>? me,
  List<Map<String, dynamic>>? products,
  List<Map<String, dynamic>> orders = const [],
  List<int> wishlist = const [],
  List<Map<String, dynamic>> users = const [],
}) => {
  'me': me,
  'products': products ?? [productJson(1), productJson(2, name: 'Oli')],
  'reviews': <Map<String, dynamic>>[],
  'orders': orders,
  'wishlist': wishlist,
  'users': users,
};

void main() {
  late FakeGateway gateway;

  void useGateway(Handler handler) {
    gateway = FakeGateway(handler);
    remoteGateway = gateway;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await auth.attach(await SharedPreferences.getInstance());
    store.products
      ..clear()
      ..addAll(Store.defaultProducts());
    store.orders.clear();
    store.reviews.clear();
    store.cart.clear();
    store.setCurrentAccount(null);
    RemoteSync.error.value = null;
  });

  tearDown(() {
    remoteGateway = null;
    auth.logout();
    store.products
      ..clear()
      ..addAll(Store.defaultProducts());
    store.orders
      ..clear()
      ..addAll(Store.defaultOrders());
    store.reviews.clear();
    store.cart.clear();
    store.wishlistIds.clear();
    store.setCurrentAccount(null);
  });

  group('HttpRemoteGateway', () {
    test('mengirim token, JSON, dan membaca jawaban', () async {
      late http.BaseRequest seen;
      String? seenBody;
      final client = MockClient((request) async {
        seen = request;
        seenBody = request.body;
        return http.Response(
          jsonEncode({'ok': true, 'nama': 'Budi ñ'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = HttpRemoteGateway('http://host/api/', client: client)
        ..token = 'abc';

      final result = await api.send('POST', '/orders', body: {'a': 1});

      expect(seen.url.toString(), 'http://host/api/orders');
      expect(seen.method, 'POST');
      expect(seen.headers['Authorization'], 'Bearer abc');
      expect(seen.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(seenBody!), {'a': 1});
      expect(result['nama'], 'Budi ñ');
    });

    test('token per panggilan menggantikan token sesi', () async {
      String? auth;
      final api = HttpRemoteGateway(
        'http://host',
        client: MockClient((r) async {
          auth = r.headers['Authorization'];
          return http.Response('{}', 200);
        }),
      )..token = 'sesi';
      await api.send('POST', '/auth/logout', token: 'lama');
      expect(auth, 'Bearer lama');
    });

    test('pesan galat server dibawa ke RemoteException', () async {
      final api = HttpRemoteGateway(
        'http://host',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'Email sudah terdaftar.'}),
            409,
          ),
        ),
      );
      await expectLater(
        api.send('POST', '/auth/register', body: {}),
        throwsA(
          isA<RemoteException>()
              .having((e) => e.message, 'message', 'Email sudah terdaftar.')
              .having((e) => e.status, 'status', 409)
              .having((e) => e.isConflict, 'isConflict', true),
        ),
      );
    });

    test('jawaban bukan JSON diberi pesan umum', () async {
      final api = HttpRemoteGateway(
        'http://host',
        client: MockClient((_) async => http.Response('<html>500</html>', 500)),
      );
      await expectLater(
        api.send('GET', '/sync'),
        throwsA(
          isA<RemoteException>().having(
            (e) => e.message,
            'message',
            'Server bermasalah (500).',
          ),
        ),
      );
    });

    test('server mati dilaporkan sebagai galat jaringan', () async {
      final api = HttpRemoteGateway(
        'http://host',
        client: MockClient((_) async => throw http.ClientException('x')),
      );
      await expectLater(
        api.send('GET', '/sync'),
        throwsA(
          isA<RemoteException>()
              .having((e) => e.isNetwork, 'isNetwork', true)
              .having((e) => e.message, 'message', contains('terhubung')),
        ),
      );
    });
  });

  group('sinkronisasi data', () {
    test(
      'produk diperbarui di tempat, yang dihapus hilang dari keranjang',
      () async {
        store.products
          ..clear()
          ..addAll([
            Product.fromJson(productJson(1, stock: 10)),
            Product.fromJson(productJson(2, name: 'Oli', stock: 5)),
          ]);
        final busi = store.products[0];
        store.addToCart(busi);
        store.addToCart(store.products[1]);

        store.applyRemoteSnapshot(
          snapshot(products: [productJson(1, price: 99000, stock: 3)]),
        );

        expect(store.products, hasLength(1));
        expect(identical(store.products.single, busi), isTrue);
        expect(busi.price, 99000);
        expect(busi.stock, 3);
        expect(store.cart, hasLength(1));
        expect(store.cart.single.product.id, 1);
      },
    );

    test('status pesanan diperbarui di tempat dan waktu menjadi lokal', () {
      store.applyRemoteSnapshot(
        snapshot(orders: [orderJson('MP-1', status: 'Menunggu Pembayaran')]),
      );
      final order = store.orders.single;
      expect(order.createdAt!.isUtc, isFalse);
      expect(order.createdAt!.toUtc().hour, 5);

      store.applyRemoteSnapshot(
        snapshot(orders: [orderJson('MP-1', status: 'Selesai')]),
      );
      expect(identical(store.orders.single, order), isTrue);
      expect(order.status, 'Selesai');
    });

    test('wishlist akun aktif diambil dari server', () {
      auth.applyRemoteSnapshot(snapshot(me: userJson()));
      store.applyRemoteSnapshot(snapshot(me: userJson(), wishlist: [2, 99]));
      expect(store.wishlistIds, {2});
    });
  });

  group('akun', () {
    test('login menyimpan token, akun, dan menarik data', () async {
      useGateway((method, path, body) {
        if (path == '/auth/login') {
          return {'token': 'a' * 64, 'user': userJson()};
        }
        return snapshot(me: userJson(), orders: [orderJson('MP-1')]);
      });

      final error = await auth.loginAsync(
        email: 'budi@mail.com',
        password: 'Rahasia1!',
        role: AccountRole.user,
      );

      expect(error, isNull);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentAccount!.id, 'u1');
      expect(gateway.token, 'a' * 64);
      expect(store.currentAccountId, 'u1');
      expect(store.ordersForCurrentAccount, hasLength(1));
      expect(gateway.bodies.first, {
        'email': 'budi@mail.com',
        'password': 'Rahasia1!',
        'role': 'user',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AuthStore.tokenKey), 'a' * 64);
    });

    test('login gagal mengembalikan pesan server', () async {
      useGateway(
        (_, _, _) => throw const RemoteException(
          'Email atau password salah.',
          status: 401,
        ),
      );
      final error = await auth.loginAsync(
        email: 'x@y.com',
        password: 'salah',
        role: AccountRole.user,
      );
      expect(error, 'Email atau password salah.');
      expect(auth.isLoggedIn, isFalse);
      expect(gateway.token, isNull);
    });

    test('daftar tidak otomatis masuk', () async {
      useGateway((_, path, _) => {'token': 'b' * 64, 'user': userJson()});
      final error = await auth.registerAsync(
        name: 'Budi',
        email: 'budi@mail.com',
        phone: '081234567890',
        password: 'Rahasia1!',
      );
      expect(error, isNull);
      expect(auth.isLoggedIn, isFalse);
      expect(gateway.token, isNull);
    });

    test('email ganda: pesan dari server', () async {
      useGateway(
        (_, _, _) =>
            throw const RemoteException('Email sudah terdaftar.', status: 409),
      );
      expect(
        await auth.registerAsync(
          name: 'Budi',
          email: 'budi@mail.com',
          phone: '081234567890',
          password: 'Rahasia1!',
        ),
        'Email sudah terdaftar.',
      );
    });

    test(
      'keluar mencabut token di server dan menghapus data pribadi',
      () async {
        useGateway(
          (_, _, _) => snapshot(me: userJson(), orders: [orderJson('MP-1')]),
        );
        gateway.token = 'c' * 64;
        await RemoteSync.pull();
        expect(auth.isLoggedIn, isTrue);
        expect(store.orders, isNotEmpty);

        auth.logout();
        await pumpEventQueue();

        expect(auth.isLoggedIn, isFalse);
        expect(gateway.token, isNull);
        expect(store.orders, isEmpty);
        expect(gateway.calls.last, 'POST /auth/logout');
        expect(gateway.tokens.last, 'c' * 64);
      },
    );

    test('token yang ditolak server membuat pengguna menjadi tamu', () async {
      useGateway((_, _, _) => snapshot());
      gateway.token = 'd' * 64;
      await RemoteSync.pull();
      expect(gateway.token, isNull);
      expect(auth.isLoggedIn, isFalse);
    });

    test('admin dengan password bawaan terdeteksi dari server', () {
      auth.applyRemoteSnapshot(
        snapshot(
          me: userJson(id: 'admin', role: 'admin', usesDefaultPassword: true),
          users: [userJson()],
        ),
      );
      useGateway((_, _, _) => snapshot());
      expect(auth.adminUsesDefaultPassword, isTrue);
      expect(auth.userAccounts, hasLength(1));
    });

    test('ganti password lewat server', () async {
      useGateway((_, _, _) => snapshot(me: userJson()));
      auth.applyRemoteSnapshot(snapshot(me: userJson()));
      expect(
        await auth.changePasswordAsync(
          oldPassword: 'a1b2c3',
          newPassword: 'x9y8z7',
        ),
        isNull,
      );
      expect(gateway.writes, ['PUT /me/password']);
      expect(gateway.bodies.first, {
        'oldPassword': 'a1b2c3',
        'newPassword': 'x9y8z7',
      });
    });

    test('ganti password ditolak: pesan server', () async {
      useGateway(
        (_, _, _) =>
            throw const RemoteException('Password lama salah.', status: 422),
      );
      expect(
        await auth.changePasswordAsync(oldPassword: 'x', newPassword: 'yyyyyy'),
        'Password lama salah.',
      );
    });
  });

  group('perubahan dikirim ke server', () {
    setUp(() {
      useGateway((_, _, _) => snapshot(me: userJson()));
      auth.applyRemoteSnapshot(snapshot(me: userJson()));
    });

    test('alamat baru membawa id aplikasi dan status alamat utama', () async {
      String? saved;
      final error = auth.addAddress(
        label: 'Rumah',
        recipient: 'Budi',
        phone: '081234567890',
        street: 'Jl. Merdeka 1',
        city: 'Pekanbaru',
        latitude: 0.5,
        longitude: 101.4,
        onSaved: (a) => saved = a.id,
      );
      expect(error, isNull);
      await pumpEventQueue();

      expect(gateway.writes, ['POST /addresses']);
      final body = gateway.bodies.first!;
      expect(body['id'], saved);
      expect(body['street'], 'Jl. Merdeka 1');
      expect(body['latitude'], 0.5);
      expect(body['makeDefault'], false);
    });

    test('profil dan metode bayar', () async {
      expect(
        auth.updateProfile(
          name: 'Budi',
          phone: '081234567890',
          motorName: 'Vario',
          motorType: 'Matic',
          motorYear: '2020',
        ),
        isNull,
      );
      await pumpEventQueue();
      expect(gateway.writes, ['PUT /me']);
      expect(gateway.bodies.first, {
        'name': 'Budi',
        'phone': '081234567890',
        'motorName': 'Vario',
        'motorType': 'Matic',
        'motorYear': 2020,
      });

      expect(auth.setPreferredPayment('QRIS'), isNull);
      await pumpEventQueue();
      expect(gateway.writes.last, 'PUT /me');
      expect(gateway.bodies[2], {'preferredPayment': 'QRIS'});
    });

    test('wishlist hanya dikirim untuk akun yang masuk', () async {
      store.products
        ..clear()
        ..add(Product.fromJson(productJson(1)));
      final busi = store.products.single;

      store.toggleWishlist(busi);
      store.toggleWishlist(busi);
      await pumpEventQueue();
      expect(gateway.writes, ['PUT /wishlist/1', 'DELETE /wishlist/1']);

      auth.logout();
      await pumpEventQueue();
      final before = gateway.writes.length;
      store.toggleWishlist(busi);
      await pumpEventQueue();
      expect(gateway.writes.length, before);
    });

    test('ubah dan hapus produk, status pesanan', () async {
      store.products
        ..clear()
        ..add(Product.fromJson(productJson(1)));
      gateway.handler = (_, _, _) => snapshot(
        me: userJson(),
        products: [productJson(1, price: 40000, stock: 7)],
        orders: [orderJson('MP-9')],
      );
      store.orders.add(OrderItem.fromJson(orderJson('MP-9')));
      final busi = store.products.single;

      store.updateProduct(busi, price: 40000, stock: 7);
      await pumpEventQueue();
      expect(gateway.writes.last, 'PUT /products/1');
      expect(
        gateway.bodies[gateway.calls.indexOf('PUT /products/1')]!['price'],
        40000,
      );

      store.updateOrderStatus(store.orders.first, 'Dikirim');
      await pumpEventQueue();
      expect(gateway.writes.last, 'PUT /orders/MP-9/status');

      store.deleteProduct(busi);
      await pumpEventQueue();
      expect(gateway.writes.last, 'DELETE /products/1');
    });

    test(
      'perubahan yang ditolak server dilaporkan dan data ditarik ulang',
      () async {
        gateway.handler = (method, path, body) {
          if (path == '/sync') return snapshot(me: userJson());
          throw const RemoteException(
            'Hanya admin yang dapat melakukan ini.',
            status: 403,
          );
        };
        store.products
          ..clear()
          ..add(Product.fromJson(productJson(1, price: 32000)));
        final busi = store.products.single;

        store.updateProduct(busi, price: 1);
        expect(busi.price, 1); // tampilan optimis
        await pumpEventQueue();

        expect(RemoteSync.error.value, 'Hanya admin yang dapat melakukan ini.');
        expect(gateway.calls.last, 'GET /sync');
      },
    );
  });

  group('pesanan', () {
    late Product busi;

    setUp(() {
      auth.applyRemoteSnapshot(snapshot(me: userJson()));
      store.products
        ..clear()
        ..add(Product.fromJson(productJson(1, stock: 5)));
      busi = store.products.single;
      store.addToCart(busi);
      store.addToCart(busi);
    });

    test('berhasil: dikirim ke server, keranjang dikosongkan', () async {
      useGateway((method, path, body) {
        if (path == '/orders') return {};
        return snapshot(
          me: userJson(),
          products: [productJson(1, stock: 3)],
          orders: [orderJson('MP-77')],
        );
      });

      final failed = await store.placeOrder(
        customer: 'Budi',
        shippingCost: 10000,
        address: 'Jl. Merdeka 1',
        paymentMethod: 'COD',
        code: 'MP-77',
      );

      expect(failed, isNull);
      expect(store.cart, isEmpty);
      expect(busi.stock, 3);
      expect(store.orderByCode('MP-77'), isNotNull);
      final body = gateway.bodies[gateway.calls.indexOf('POST /orders')]!;
      expect(body['code'], 'MP-77');
      expect(body['shippingCost'], 10000);
      expect(body['lines'], [
        {'productId': 1, 'qty': 2},
      ]);
      expect(body.containsKey('price'), isFalse);
    });

    test('stok kurang: mengembalikan masalah dan keranjang tetap', () async {
      useGateway((method, path, body) {
        if (path == '/orders') {
          throw const RemoteException('Stok Busi NGK tinggal 1.', status: 409);
        }
        return snapshot(me: userJson(), products: [productJson(1, stock: 1)]);
      });

      final failed = await store.placeOrder(customer: 'Budi', shippingCost: 0);

      expect(failed, ['Stok Busi NGK tinggal 1.']);
      expect(store.cart, hasLength(1));
      expect(busi.stock, 1); // ditarik ulang dari server
      expect(store.cartStockProblems, isNotEmpty);
    });

    test('server tidak terjangkau: dilempar, keranjang aman', () async {
      useGateway(
        (_, _, _) =>
            throw const RemoteException('Tidak dapat terhubung ke server.'),
      );
      await expectLater(
        store.placeOrder(customer: 'Budi', shippingCost: 0),
        throwsA(isA<RemoteException>()),
      );
      expect(store.cart, hasLength(1));
    });

    test('pembayaran online membawa data tagihan', () async {
      useGateway((method, path, body) => snapshot(me: userJson()));
      await store.placeOrder(
        customer: 'Budi',
        shippingCost: 0,
        paymentMethod: 'QRIS',
        payment: const PaymentInfo(
          paymentId: 'pay-1',
          type: 'qris',
          amount: 32000,
          qrString: 'QR',
        ),
      );
      final body = gateway.bodies[gateway.calls.indexOf('POST /orders')]!;
      expect(body['payment'], isA<Map>());
      expect((body['payment'] as Map)['paymentId'], 'pay-1');
    });
  });

  group('kategori', () {
    setUp(() {
      useGateway((_, _, _) => snapshot(me: userJson()));
      auth.applyRemoteSnapshot(snapshot(me: userJson()));
      store.categories
        ..clear()
        ..addAll(Store.defaultCategories());
    });

    tearDown(() {
      store.categories
        ..clear()
        ..addAll(Store.defaultCategories());
    });

    test('snapshot server mengganti daftar kategori', () {
      store.applyRemoteSnapshot({
        ...snapshot(),
        'categories': [
          {'name': 'Aki', 'icon': 'electric_bolt'},
          {'name': 'Rem', 'icon': 'album'},
        ],
      });
      expect(store.categoryNames, ['Aki', 'Rem']);
      expect(store.categories.first.iconKey, 'electric_bolt');
    });

    test('server lama tanpa kategori: daftar lokal dipertahankan', () {
      store.applyRemoteSnapshot(snapshot());
      expect(store.categoryNames, Store.defaultCategories().map((c) => c.name));
    });

    test('tambah, ubah, hapus dikirim ke alamat yang benar', () async {
      store.addCategory('Aki dan Kabel', 'electric_bolt');
      await pumpEventQueue();
      expect(gateway.writes, ['POST /categories']);
      expect(gateway.bodies.first, {
        'name': 'Aki dan Kabel',
        'icon': 'electric_bolt',
      });

      final aki = store.categories.last;
      store.updateCategory(aki, name: 'Aki', iconKey: 'build');
      await pumpEventQueue();
      expect(gateway.writes.last, 'PUT /categories/Aki%20dan%20Kabel');
      expect(
        gateway.bodies[gateway.calls.indexOf(
          'PUT /categories/Aki%20dan%20Kabel',
        )],
        {'name': 'Aki', 'icon': 'build'},
      );

      store.deleteCategory(store.categories.last);
      await pumpEventQueue();
      expect(gateway.writes.last, 'DELETE /categories/Aki');
    });

    test('urutan baru dikirim sebagai daftar nama', () async {
      final names = store.categoryNames;
      store.moveCategory(0, 3);
      await pumpEventQueue();
      expect(gateway.writes, ['POST /categories/reorder']);
      expect(gateway.bodies.first, {
        'names': [names[1], names[2], names[3], names[0], ...names.skip(4)],
      });
    });

    test('kategori yang ditolak lokal tidak dikirim', () async {
      store.addCategory('Mesin', 'build'); // ganda
      store.deleteCategory(store.categories.first); // masih dipakai produk
      await pumpEventQueue();
      expect(gateway.writes, isEmpty);
    });
  });

  group('produk baru', () {
    test('dibuat di server (id dari database)', () async {
      useGateway((method, path, body) {
        if (path == '/products') return {'product': productJson(13)};
        return snapshot(
          products: [
            productJson(1),
            productJson(13, name: 'Kampas Baru'),
          ],
        );
      });

      final error = await store.createProduct(
        name: 'Kampas Baru',
        category: 'Rem',
        type: 'Matic',
        price: 45000,
        stock: 5,
        description: 'Baru',
      );

      expect(error, isNull);
      expect(store.products.map((p) => p.id), [1, 13]);
      expect(
        gateway.bodies[gateway.calls.indexOf('POST /products')]!['price'],
        45000,
      );
    });

    test('ditolak server: pesan ditampilkan', () async {
      useGateway(
        (_, _, _) => throw const RemoteException(
          'Hanya admin yang dapat melakukan ini.',
          status: 403,
        ),
      );
      expect(
        await store.createProduct(
          name: 'X',
          category: 'Rem',
          type: 'Matic',
          price: 1,
          stock: 1,
          description: '',
        ),
        'Hanya admin yang dapat melakukan ini.',
      );
    });
  });

  test('mode lokal tidak memanggil server sama sekali', () async {
    expect(remoteGateway, isNull);
    expect(auth.isRemote, isFalse);
    expect(store.isRemote, isFalse);
    // Tidak ada gateway: perubahan hanya lokal dan tidak melempar apa pun.
    store.toggleWishlist(store.products.first);
    expect(
      await store.createProduct(
        name: 'Lokal',
        category: 'Rem',
        type: 'Matic',
        price: 1000,
        stock: 1,
        description: '',
      ),
      isNull,
    );
    expect(store.products.last.name, 'Lokal');
  });
}
