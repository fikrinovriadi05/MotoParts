import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/pages/user/cart_page.dart';
import 'package:motopart/pages/user/product_detail_page.dart';
import 'package:motopart/pages/user/product_image_viewer.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/order_timeline.dart';
import 'package:motopart/widgets/product_card.dart';

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late Directory tmp;

  setUp(() {
    UiConfig.animate = true;
    final fresh = Store();
    store.products
      ..clear()
      ..addAll(fresh.products);
    store.setCurrentAccount(Store.guestId);
    store.cart.clear();
    tmp = Directory.systemTemp.createTempSync('motopart_zoom_');
  });
  tearDown(() {
    UiConfig.animate = false;
    tmp.deleteSync(recursive: true);
  });

  String newPhoto() {
    final file = File('${tmp.path}/foto.png')..writeAsBytesSync(_pngBytes);
    return file.path;
  }

  // ---------------------------------------------------------------- zoom
  group('Pembesar gambar produk', () {
    Future<void> openViewer(WidgetTester tester, {String? photo}) async {
      bigScreen(tester);
      final product = store.products[0];
      product.imagePath = photo;
      await tester.pumpWidget(app(ProductDetailPage(product: product)));
      await tester.tap(find.byType(ProductImage));
      await tester.pumpAndSettle();
    }

    TransformationController controllerOf(WidgetTester tester) => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;

    double scaleNow(WidgetTester tester) =>
        ProductImageViewer.scaleOf(controllerOf(tester).value);

    Future<void> doubleTap(WidgetTester tester, Offset at) async {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(at);
      // Beberapa frame: animasi baru mulai setelah pewaktu ketuk-ganda (40 ms).
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('mengetuk gambar di detail membuka pembesar dan bisa ditutup', (
      tester,
    ) async {
      await openViewer(tester);

      expect(find.byType(ProductImageViewer), findsOneWidget);
      expect(find.text(store.products[0].name), findsWidgets);
      expect(find.text('Cubit atau ketuk dua kali'), findsOneWidget);

      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductImageViewer), findsNothing);
      expect(find.byType(ProductDetailPage), findsOneWidget);
    });

    testWidgets(
      'gambar di detail punya petunjuk dan label untuk pembaca layar',
      (tester) async {
        bigScreen(tester);
        final product = store.products[0];
        await tester.pumpWidget(app(ProductDetailPage(product: product)));

        expect(find.byIcon(Icons.zoom_out_map_rounded), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            'Gambar ${product.name}, ketuk untuk memperbesar',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('batas zoom 1x sampai 5x dan awalnya tidak diperbesar', (
      tester,
    ) async {
      await openViewer(tester);

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.minScale, 1);
      expect(viewer.maxScale, ProductImageViewer.maxScale);
      expect(scaleNow(tester), 1.0);
    });

    testWidgets(
      'ketuk dua kali: memperbesar di titik ketukan, lalu mengembalikan',
      (tester) async {
        await openViewer(tester);
        final target = const Offset(300, 700);

        await doubleTap(tester, target);
        expect(
          scaleNow(tester),
          closeTo(ProductImageViewer.doubleTapScale, 0.01),
        );
        // Titik yang diketuk tetap di tempatnya (zoom berpusat di sana).
        final moved = MatrixUtils.transformPoint(
          controllerOf(tester).value,
          target,
        );
        expect(moved.dx, closeTo(target.dx, 0.5));
        expect(moved.dy, closeTo(target.dy, 0.5));

        await doubleTap(tester, target);
        expect(scaleNow(tester), closeTo(1.0, 0.01));
      },
    );

    testWidgets('animasi mati: zoom langsung tanpa menunggu', (tester) async {
      UiConfig.animate = false;
      await openViewer(tester);

      await tester.tapAt(const Offset(300, 700));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(const Offset(300, 700));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        scaleNow(tester),
        closeTo(ProductImageViewer.doubleTapScale, 0.01),
      );
    });

    testWidgets('cubit dengan dua jari memperbesar', (tester) async {
      await openViewer(tester);
      final center = tester.getCenter(find.byType(InteractiveViewer));

      final a = await tester.startGesture(center - const Offset(20, 0));
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 2,
      );
      for (var i = 0; i < 5; i++) {
        await a.moveBy(const Offset(-25, 0));
        await b.moveBy(const Offset(25, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pump(const Duration(milliseconds: 100));

      expect(scaleNow(tester), greaterThan(1.5));
      expect(scaleNow(tester), lessThanOrEqualTo(ProductImageViewer.maxScale));
    });

    testWidgets('produk dengan foto: ditampilkan utuh (contain)', (
      tester,
    ) async {
      await openViewer(tester, photo: newPhoto());

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(ProductImageViewer),
          matching: find.byType(Image),
        ),
      );
      expect(image.fit, BoxFit.contain);
    });

    testWidgets('produk tanpa foto: ikon produk yang diperbesar', (
      tester,
    ) async {
      await openViewer(tester);

      expect(
        find.descendant(
          of: find.byType(ProductImageViewer),
          matching: find.byIcon(store.products[0].icon),
        ),
        findsOneWidget,
      );
    });

    testWidgets('berbagi tag Hero dengan gambar di detail', (tester) async {
      await openViewer(tester);

      final tags = tester
          .widgetList<Hero>(find.byType(Hero, skipOffstage: false))
          .map((h) => h.tag)
          .toList();
      expect(
        tags.where((t) => t == productHeroTag(store.products[0])).length,
        2,
      );
    });

    testWidgets('tombol kembali sistem menutup pembesar', (tester) async {
      await openViewer(tester);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(ProductImageViewer), findsNothing);
    });
  });

  // ------------------------------------------------------------ timeline
  group('Lini masa terisi bertahap', () {
    Future<void> pumpTimeline(
      WidgetTester tester,
      ValueNotifier<String> status,
    ) => tester.pumpWidget(
      app(
        Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (_, s, _) => OrderTimeline(status: s),
          ),
        ),
      ),
    );

    int checks(WidgetTester tester) =>
        find.byIcon(Icons.check_rounded).evaluate().length;

    List<double> factors(WidgetTester tester) => tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .map((b) => b.widthFactor!)
        .toList();

    testWidgets(
      'Dikirim: mulai kosong, terisi bertahap, berakhir di langkah ke-3',
      (tester) async {
        await pumpTimeline(tester, ValueNotifier('Dikirim'));

        // Frame pertama: belum ada langkah selesai, semua garis kosong.
        expect(checks(tester), 0);
        expect(factors(tester).every((f) => f == 0), isTrue);

        // Di tengah jalan: sebagian garis terisi sebagian.
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          factors(tester).any((f) => f > 0 && f < 1),
          isTrue,
          reason: 'ada garis yang sedang terisi',
        );

        await tester.pumpAndSettle();
        expect(checks(tester), 2); // Diproses & Dikemas selesai
        final f = factors(tester);
        expect(f.where((x) => x == 1).length, 4);
        expect(f.where((x) => x == 0).length, 2);
      },
    );

    testWidgets('Diproses: tidak ada yang perlu beranimasi', (tester) async {
      await pumpTimeline(tester, ValueNotifier('Diproses'));

      expect(checks(tester), 0);
      expect(factors(tester).every((f) => f == 0), isTrue);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('Selesai: semua langkah sebelumnya bercentang', (tester) async {
      await pumpTimeline(tester, ValueNotifier('Selesai'));
      await tester.pumpAndSettle();

      expect(checks(tester), 3);
      expect(factors(tester).every((f) => f == 1), isTrue);
    });

    testWidgets('status berubah: hanya selisihnya yang beranimasi', (
      tester,
    ) async {
      final status = ValueNotifier('Dikemas');
      await pumpTimeline(tester, status);
      await tester.pumpAndSettle();
      expect(checks(tester), 1);

      status.value = 'Dikirim';
      await tester.pump();

      // Langkah yang sudah selesai tidak ikut dikosongkan ulang.
      expect(checks(tester), 1);
      await tester.pumpAndSettle();
      expect(checks(tester), 2);
    });

    testWidgets('animasi mati: langsung menampilkan hasil akhir', (
      tester,
    ) async {
      UiConfig.animate = false;
      await pumpTimeline(tester, ValueNotifier('Dikirim'));

      expect(checks(tester), 2);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('semua label langkah tampil', (tester) async {
      await pumpTimeline(tester, ValueNotifier('Dikirim'));
      await tester.pumpAndSettle();

      for (final label in OrderTimeline.steps) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('dibatalkan dan menunggu pembayaran tetap berupa banner', (
      tester,
    ) async {
      await pumpTimeline(tester, ValueNotifier(Store.cancelledStatus));
      expect(find.text('Pesanan ini dibatalkan.'), findsOneWidget);
      expect(find.byType(FractionallySizedBox), findsNothing);

      await pumpTimeline(tester, ValueNotifier(Store.awaitingPaymentStatus));
      expect(
        find.text('Menunggu pembayaran. Pesanan diproses setelah dibayar.'),
        findsOneWidget,
      );
    });

    testWidgets('tidak overflow di layar kecil dengan teks besar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpTimeline(tester, ValueNotifier('Selesai'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------- cart
  group('Keranjang: animasi hapus', () {
    Future<void> pumpCart(WidgetTester tester) async {
      bigScreen(tester);
      store.addToCart(store.products[0]);
      store.addToCart(store.products[1]);
      await tester.pumpWidget(app(const CartPage()));
      await tester.pump();
    }

    double smallestSize(WidgetTester tester) => tester
        .widgetList<SizeTransition>(find.byType(SizeTransition))
        .map((t) => t.sizeFactor.value)
        .reduce((a, b) => a < b ? a : b);

    testWidgets('tombol hapus: baris menciut dulu, lalu item dihapus', (
      tester,
    ) async {
      await pumpCart(tester);
      final name = store.products[0].name;
      expect(smallestSize(tester), 1.0);

      await tester.tap(find.byTooltip('Hapus $name'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      // Sedang menciut: item masih ada di keranjang.
      expect(store.qtyInCart(store.products[0]), 1);
      expect(smallestSize(tester), lessThan(1.0));
      expect(smallestSize(tester), greaterThan(0.0));

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(store.qtyInCart(store.products[0]), 0);
      expect(store.qtyInCart(store.products[1]), 1);
      expect(find.text(name), findsNothing);
      expect(find.text('$name dihapus dari keranjang'), findsOneWidget);
    });

    testWidgets('Batal mengembalikan item dengan jumlah semula', (
      tester,
    ) async {
      await pumpCart(tester);
      final p = store.products[0];
      store.addToCart(p); // jumlah 2
      await tester.pump();

      await tester.tap(find.byTooltip('Hapus ${p.name}'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(store.qtyInCart(p), 0);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(store.qtyInCart(p), 2);
      expect(find.text(p.name), findsOneWidget);
      expect(smallestSize(tester), 1.0); // baris yang kembali tampil utuh
    });

    testWidgets('ketukan hapus berulang saat animasi: hanya sekali dihapus', (
      tester,
    ) async {
      await pumpCart(tester);
      final p = store.products[0];

      await tester.tap(find.byTooltip('Hapus ${p.name}'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byTooltip('Hapus ${p.name}'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byTooltip('Hapus ${p.name}'));
      await tester.pumpAndSettle();

      expect(store.qtyInCart(p), 0);
      expect(find.text('${p.name} dihapus dari keranjang'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('menghapus item terakhir menampilkan keranjang kosong', (
      tester,
    ) async {
      bigScreen(tester);
      final p = store.products[0];
      store.addToCart(p);
      await tester.pumpWidget(app(const CartPage()));

      await tester.tap(find.byTooltip('Hapus ${p.name}'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Keranjang masih kosong'), findsOneWidget);
    });

    testWidgets('geser untuk menghapus tetap berfungsi', (tester) async {
      await pumpCart(tester);
      final p = store.products[0];

      await tester.drag(find.byType(Dismissible).first, const Offset(-700, 0));
      await tester.pumpAndSettle();

      expect(store.qtyInCart(p), 0);
      expect(store.qtyInCart(store.products[1]), 1);
    });

    testWidgets('animasi mati: langsung dihapus', (tester) async {
      UiConfig.animate = false;
      await pumpCart(tester);
      final p = store.products[0];

      await tester.tap(find.byTooltip('Hapus ${p.name}'));
      await tester.pump();

      expect(store.qtyInCart(p), 0);
      expect(find.text(p.name), findsNothing);
    });

    testWidgets('mengubah jumlah tidak memutar animasi hapus', (tester) async {
      await pumpCart(tester);
      final p = store.products[1];

      await tester.tap(find.byTooltip('Tambah jumlah ${p.name}'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(smallestSize(tester), 1.0);
      expect(store.qtyInCart(p), 2);
    });
  });
}
