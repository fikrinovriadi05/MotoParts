import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/user/cart_page.dart';
import 'package:motopart/pages/user/payment_success_page.dart';
import 'package:motopart/pages/user/product_detail_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/confetti.dart';
import 'package:motopart/widgets/motion.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/product_card.dart';
import 'package:motopart/widgets/product_grid.dart';
import 'package:motopart/widgets/wishlist_button.dart';

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Mencatat getaran yang diminta aplikasi ("lightImpact", "selectionClick", ...).
List<String> captureHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add('${call.arguments}'.replaceFirst('HapticFeedbackType.', ''));
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

double opacityOf(WidgetTester tester, Finder within) => tester
    .widget<Opacity>(
      find.descendant(of: within, matching: find.byType(Opacity)).first,
    )
    .opacity;

Future<void> dispose(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

void main() {
  setUp(() {
    UiConfig.animate = true;
    final fresh = Store();
    store.products
      ..clear()
      ..addAll(fresh.products);
    store.setCurrentAccount(Store.guestId);
    store.cart.clear();
    store.wishlistIds.clear();
  });
  tearDown(() => UiConfig.animate = false);

  group('UiConfig.motion', () {
    test('durasi hanya berlaku saat animasi aktif', () {
      const d = Duration(milliseconds: 300);
      expect(UiConfig.motion(d), d);
      UiConfig.animate = false;
      expect(UiConfig.motion(d), Duration.zero);
    });
  });

  group('FadeSlideIn', () {
    testWidgets('mulai transparan lalu muncul penuh', (tester) async {
      await tester.pumpWidget(app(const FadeSlideIn(child: Text('halo'))));
      final box = find.byType(FadeSlideIn);

      expect(opacityOf(tester, box), 0);
      await tester.pump(const Duration(milliseconds: 100));
      final mid = opacityOf(tester, box);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await tester.pump(const Duration(milliseconds: 600));
      expect(opacityOf(tester, box), 1);
      expect(find.text('halo'), findsOneWidget);
    });

    testWidgets('item berikutnya mulai sedikit lebih lambat', (tester) async {
      await tester.pumpWidget(
        app(
          const Column(
            children: [
              FadeSlideIn(index: 0, key: Key('a'), child: Text('satu')),
              FadeSlideIn(index: 6, key: Key('b'), child: Text('tujuh')),
            ],
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));

      expect(
        opacityOf(tester, find.byKey(const Key('a'))),
        greaterThan(opacityOf(tester, find.byKey(const Key('b')))),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(opacityOf(tester, find.byKey(const Key('b'))), 1);
    });

    testWidgets('tundaan dibatasi untuk indeks besar', (tester) async {
      await tester.pumpWidget(
        app(const FadeSlideIn(index: 500, child: Text('jauh'))),
      );

      // 8 langkah * 45 ms + 380 ms = 740 ms, bukan 500 langkah.
      await tester.pump(const Duration(milliseconds: 800));
      expect(opacityOf(tester, find.byType(FadeSlideIn)), 1);
    });

    testWidgets('animasi mati: anak langsung tampil tanpa Opacity', (
      tester,
    ) async {
      UiConfig.animate = false;
      await tester.pumpWidget(app(const FadeSlideIn(child: Text('langsung'))));

      expect(find.byType(Opacity), findsNothing);
      expect(find.text('langsung'), findsOneWidget);
    });
  });

  group('AnimatedCount dan AnimatedNumber', () {
    Future<ValueNotifier<int>> pumpCount(WidgetTester tester) async {
      final value = ValueNotifier<int>(100);
      await tester.pumpWidget(
        app(
          ValueListenableBuilder<int>(
            valueListenable: value,
            builder: (_, v, _) =>
                AnimatedCount(value: v, builder: (n) => 'Rp$n'),
          ),
        ),
      );
      return value;
    }

    testWidgets('nilai awal langsung tampil, perubahan berhitung bertahap', (
      tester,
    ) async {
      final value = await pumpCount(tester);
      expect(find.text('Rp100'), findsOneWidget);

      value.value = 500;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final shown = tester.widget<Text>(find.byType(Text)).data!;
      final n = int.parse(shown.substring(2));
      expect(n, greaterThan(100));
      expect(n, lessThan(500));

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Rp500'), findsOneWidget);
    });

    testWidgets('animasi mati: langsung ke nilai baru', (tester) async {
      UiConfig.animate = false;
      final value = await pumpCount(tester);

      value.value = 500;
      await tester.pump();

      expect(find.text('Rp500'), findsOneWidget);
    });

    testWidgets('AnimatedNumber: angka lama memudar, angka baru masuk', (
      tester,
    ) async {
      final value = ValueNotifier<int>(1);
      await tester.pumpWidget(
        app(
          ValueListenableBuilder<int>(
            valueListenable: value,
            builder: (_, v, _) => AnimatedNumber(value: v),
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);

      value.value = 2;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('1'), findsOneWidget); // masih memudar
      expect(find.text('2'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('Haptics', () {
    testWidgets('light dan selection mengirim getaran yang tepat', (
      tester,
    ) async {
      final calls = captureHaptics(tester);

      Haptics.light();
      Haptics.selection();
      await tester.pump();

      expect(calls, ['lightImpact', 'selectionClick']);
    });
  });

  group('WishlistButton', () {
    Future<void> pumpHeart(WidgetTester tester, Product p) => tester.pumpWidget(
      app(
        Scaffold(
          body: Center(child: WishlistButton(product: p)),
        ),
      ),
    );

    double maxScale(WidgetTester tester) => tester
        .widgetList<ScaleTransition>(
          find.descendant(
            of: find.byType(WishlistButton),
            matching: find.byType(ScaleTransition),
          ),
        )
        .map((t) => t.scale.value)
        .reduce((a, b) => a > b ? a : b);

    testWidgets(
      'menyukai: hati membal lalu kembali normal, perangkat bergetar',
      (tester) async {
        final calls = captureHaptics(tester);
        final p = store.products[0];
        await pumpHeart(tester, p);
        expect(maxScale(tester), 1.0);

        await tester.tap(find.byType(IconButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(store.isWishlisted(p), isTrue);
        expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
        expect(maxScale(tester), greaterThan(1.05));
        expect(calls, ['lightImpact']);

        await tester.pump(const Duration(seconds: 1));
        expect(maxScale(tester), closeTo(1.0, 0.001));
        await dispose(tester);
      },
    );

    testWidgets('batal menyukai: tanpa getaran dan tanpa membal', (
      tester,
    ) async {
      final calls = captureHaptics(tester);
      final p = store.products[0];
      store.toggleWishlist(p);
      await pumpHeart(tester, p);

      await tester.tap(find.byType(IconButton));
      await tester.pump(const Duration(milliseconds: 120));

      expect(store.isWishlisted(p), isFalse);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(maxScale(tester), 1.0);
      expect(calls, isEmpty);
      await dispose(tester);
    });

    testWidgets('perubahan dari tempat lain juga memutar animasi', (
      tester,
    ) async {
      final p = store.products[0];
      await pumpHeart(tester, p);

      store.toggleWishlist(p); // mis. dari halaman detail
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(maxScale(tester), greaterThan(1.05));
      await tester.pump(const Duration(seconds: 1));
      await dispose(tester);
    });

    testWidgets('animasi mati: hati langsung berubah tanpa membal', (
      tester,
    ) async {
      UiConfig.animate = false;
      final p = store.products[0];
      await pumpHeart(tester, p);

      await tester.tap(find.byType(IconButton));
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(maxScale(tester), 1.0);
    });
  });

  group('Tombol + pada kartu produk', () {
    Future<void> pumpCard(WidgetTester tester, Product p) async {
      bigScreen(tester);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: ProductCard.extent,
                child: ProductCard(product: p, onTap: () {}),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('berhasil menambah: jadi centang sebentar, lalu kembali +', (
      tester,
    ) async {
      final calls = captureHaptics(tester);
      final p = store.products[0];
      await pumpCard(tester, p);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(); // ikon lama dilepas satu frame setelah transisi

      expect(store.qtyInCart(p), 1);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      expect(calls, ['lightImpact']);

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await dispose(tester);
    });

    testWidgets(
      'ketukan berulang saat centang: tetap menambah dan memperpanjang',
      (tester) async {
        final p = store.products[0];
        await pumpCard(tester, p);

        await tester.tap(find.byType(InkResponse));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.byType(InkResponse));
        await tester.pump(const Duration(milliseconds: 600));

        expect(store.qtyInCart(p), 2);
        // 1,2 detik sejak ketukan pertama, tetapi ketukan kedua memperpanjang.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
        await dispose(tester);
      },
    );

    testWidgets('stok penuh: tidak berubah jadi centang dan tanpa getaran', (
      tester,
    ) async {
      final calls = captureHaptics(tester);
      final p = store.products[0];
      p.stock = 1;
      store.addToCart(p); // keranjang sudah sebanyak stok
      await pumpCard(tester, p);

      await tester.tap(find.byType(InkResponse));
      await tester.pump(const Duration(milliseconds: 300));

      expect(store.qtyInCart(p), 1);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(calls, isEmpty);
      await dispose(tester);
    });

    testWidgets('stok habis: tombol nonaktif', (tester) async {
      final p = store.products[0];
      p.stock = 0;
      await pumpCard(tester, p);

      await tester.tap(find.byType(InkResponse));
      await tester.pump(const Duration(milliseconds: 300));

      expect(store.qtyInCart(p), 0);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('animasi mati: menambah tanpa centang dan tanpa timer', (
      tester,
    ) async {
      UiConfig.animate = false;
      final p = store.products[0];
      await pumpCard(tester, p);

      await tester.tap(find.byType(InkResponse));
      await tester.pump();

      expect(store.qtyInCart(p), 1);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });

  group('Grid produk muncul bergantian', () {
    testWidgets('awalnya transparan, lalu semua tampil dan bisa dibuka', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: ProductGrid(products: store.products.take(4).toList()),
          ),
        ),
      );

      final cards = find.byType(FadeSlideIn);
      expect(cards, findsNWidgets(4));
      expect(opacityOf(tester, cards.first), 0);

      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        expect(opacityOf(tester, cards.at(i)), 1, reason: 'kartu $i');
      }

      await tester.tap(find.text(store.products.first.name));
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailPage), findsOneWidget);
    });
  });

  group('Keranjang: angka bergerak', () {
    testWidgets('jumlah dan subtotal berganti dengan animasi', (tester) async {
      bigScreen(tester);
      final p = store.products[1]; // Rp 25.000
      store.addToCart(p);
      await tester.pumpWidget(app(const CartPage()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(formatRupiah(25000)), findsWidgets);

      await tester.tap(find.byTooltip('Tambah jumlah ${p.name}'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      // Angka jumlah: lama dan baru berdampingan sesaat.
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsOneWidget);
      // Subtotal: di antara nilai lama dan baru.
      final totals = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((t) => t.startsWith('Rp') && t != formatRupiah(25000));
      expect(totals.contains(formatRupiah(50000)), isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(formatRupiah(50000)), findsWidgets);
      expect(find.text('1'), findsNothing);
      await dispose(tester);
    });
  });

  group('PrimaryButton: efek tekan', () {
    double scaleOf(WidgetTester tester) => tester
        .widget<AnimatedScale>(
          find.descendant(
            of: find.byType(PrimaryButton),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;

    for (final outline in [false, true]) {
      testWidgets(
        'mengecil saat ditekan dan kembali saat dilepas (outline: $outline)',
        (tester) async {
          var taps = 0;
          await tester.pumpWidget(
            app(
              Scaffold(
                body: PrimaryButton(
                  text: 'Bayar',
                  outline: outline,
                  onPressed: () => taps++,
                ),
              ),
            ),
          );
          expect(scaleOf(tester), 1.0);

          final gesture = await tester.startGesture(
            tester.getCenter(find.text('Bayar')),
          );
          await tester.pump(const Duration(milliseconds: 150));
          expect(scaleOf(tester), 0.97);

          await gesture.up();
          await tester.pump(const Duration(milliseconds: 150));
          expect(scaleOf(tester), 1.0);
          expect(taps, 1);
        },
      );
    }

    testWidgets('dinonaktifkan: tidak mengecil dan tidak memicu aksi', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const Scaffold(body: PrimaryButton(text: 'Bayar', onPressed: null)),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Bayar')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(scaleOf(tester), 1.0);
      await gesture.up();
    });

    testWidgets('batal di tengah sentuhan: kembali ke ukuran normal', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: PrimaryButton(text: 'Bayar', onPressed: () {}),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Bayar')),
      );
      await tester.pump(const Duration(milliseconds: 150));

      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 150));

      expect(scaleOf(tester), 1.0);
    });
  });

  group('Konfeti', () {
    testWidgets('berjalan lalu hilang sendiri, tanpa menghalangi sentuhan', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Stack(
              children: [
                Center(
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('di bawah'),
                  ),
                ),
                const Positioned.fill(child: Confetti()),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 800));
      expect(
        find.descendant(
          of: find.byType(Confetti),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('di bawah'));
      expect(taps, 1);

      await tester.pump(Confetti.duration);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(Confetti),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('animasi mati: tidak menampilkan apa pun', (tester) async {
      UiConfig.animate = false;
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: Stack(children: [Positioned.fill(child: Confetti())]),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(Confetti),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'halaman sukses pembayaran menampilkan konfeti dan tetap bisa dipakai',
      (tester) async {
        bigScreen(tester);
        await tester.pumpWidget(app(const PaymentSuccessPage()));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(Confetti), findsOneWidget);
        expect(find.text('Pembayaran Berhasil!'), findsOneWidget);
        expect(find.text('Lihat Pesanan'), findsOneWidget);

        await tester.pump(Confetti.duration);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('jumlah dan warna konfeti sesuai pengaturan', (tester) async {
      expect(Confetti.colors, isNotEmpty);
      expect(const Confetti().count, 46);
      expect(const Confetti(count: 10).count, 10);
    });
  });
}
