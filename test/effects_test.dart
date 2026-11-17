import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/pages/admin/admin_dashboard_page.dart';
import 'package:motopart/pages/admin/admin_reports_page.dart';
import 'package:motopart/pages/user/home_page.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/motion.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/product_card.dart';

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

Future<TestGesture> newMouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(1, 1));
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

Future<void> dispose(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox());

double opacityOf(WidgetTester tester, Finder within) => tester
    .widget<Opacity>(
      find.descendant(of: within, matching: find.byType(Opacity)).first,
    )
    .opacity;

/// Tegak = tanpa putaran. Matriks selalu memuat entri perspektif (3,2), jadi
/// bukan identitas penuh; yang diperiksa hanya bagian putarannya.
bool isUpright(Matrix4 m) =>
    m.entry(0, 2).abs() < 1e-9 &&
    m.entry(1, 2).abs() < 1e-9 &&
    m.entry(2, 0).abs() < 1e-9 &&
    m.entry(2, 1).abs() < 1e-9;

Finder shine() => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is ShinePainter,
);

void main() {
  setUp(() {
    UiConfig.animate = true;
    final fresh = Store();
    store.products
      ..clear()
      ..addAll(fresh.products);
    store.orders
      ..clear()
      ..addAll(fresh.orders);
    store.setCurrentAccount(Store.guestId);
    store.cart.clear();
  });
  tearDown(() => UiConfig.animate = false);

  // ------------------------------------------------------ AnimatedCount
  group('AnimatedCount.fromZero', () {
    Widget count({bool fromZero = true, int value = 250}) => app(
      Scaffold(
        body: AnimatedCount(
          value: value,
          fromZero: fromZero,
          builder: (v) => 'N$v',
        ),
      ),
    );

    testWidgets('mulai dari 0 lalu naik ke nilai akhir', (tester) async {
      await tester.pumpWidget(count());
      expect(find.text('N0'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      final shown = tester.widget<Text>(find.byType(Text)).data!;
      final n = int.parse(shown.substring(1));
      expect(n, greaterThan(0));
      expect(n, lessThan(250));

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('N250'), findsOneWidget);
    });

    testWidgets('tanpa fromZero: nilai langsung tampil', (tester) async {
      await tester.pumpWidget(count(fromZero: false));
      expect(find.text('N250'), findsOneWidget);
    });

    testWidgets('animasi mati: nilai akhir langsung, walau fromZero', (
      tester,
    ) async {
      UiConfig.animate = false;
      await tester.pumpWidget(count());
      expect(find.text('N250'), findsOneWidget);
    });

    testWidgets(
      'perubahan berikutnya berhitung dari nilai sekarang, bukan dari 0',
      (tester) async {
        await tester.pumpWidget(count());
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('N250'), findsOneWidget);

        await tester.pumpWidget(count(value: 400));
        await tester.pump(const Duration(milliseconds: 100));

        final n = int.parse(
          tester.widget<Text>(find.byType(Text)).data!.substring(1),
        );
        expect(n, greaterThanOrEqualTo(250));
        expect(n, lessThanOrEqualTo(400));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('N400'), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------- PopIn
  group('PopIn', () {
    double scaleOf(WidgetTester tester) => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(PopIn),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage[0];

    testWidgets('mulai kecil dan transparan lalu melompat ke ukuran penuh', (
      tester,
    ) async {
      await tester.pumpWidget(app(const PopIn(child: Text('halo'))));
      expect(opacityOf(tester, find.byType(PopIn)), 0);
      expect(scaleOf(tester), closeTo(0.6, 0.001));

      await tester.pump(const Duration(milliseconds: 150));
      expect(scaleOf(tester), greaterThan(0.6));

      await tester.pump(const Duration(seconds: 1));
      expect(opacityOf(tester, find.byType(PopIn)), 1);
      expect(scaleOf(tester), closeTo(1.0, 0.001));
      expect(find.text('halo'), findsOneWidget);
    });

    testWidgets('skala awal bisa diatur', (tester) async {
      await tester.pumpWidget(app(const PopIn(from: 0.2, child: Text('x'))));
      expect(scaleOf(tester), closeTo(0.2, 0.001));
    });

    testWidgets('item dengan indeks lebih besar mulai lebih lambat', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const Column(
            children: [
              PopIn(index: 0, key: Key('a'), child: Text('satu')),
              PopIn(index: 5, key: Key('b'), child: Text('enam')),
            ],
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(
        opacityOf(tester, find.byKey(const Key('a'))),
        greaterThan(opacityOf(tester, find.byKey(const Key('b')))),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(opacityOf(tester, find.byKey(const Key('b'))), 1);
    });

    testWidgets('membangun ulang tidak memutar animasi lagi', (tester) async {
      await tester.pumpWidget(app(const PopIn(child: Text('x'))));
      await tester.pump(const Duration(seconds: 1));

      await tester.pumpWidget(app(const PopIn(child: Text('x'))));
      await tester.pump();

      expect(opacityOf(tester, find.byType(PopIn)), 1);
    });

    testWidgets('animasi mati: anak langsung tampil', (tester) async {
      UiConfig.animate = false;
      await tester.pumpWidget(app(const PopIn(child: Text('langsung'))));

      expect(find.byType(Opacity), findsNothing);
      expect(find.text('langsung'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------- TiltOnHover
  group('TiltOnHover', () {
    Future<void> pumpTilt(WidgetTester tester, {bool enabled = true}) =>
        tester.pumpWidget(
          app(
            Center(
              child: TiltOnHover(
                enabled: enabled,
                child: const SizedBox(width: 200, height: 200),
              ),
            ),
          ),
        );

    Matrix4 matrix(WidgetTester tester) => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(TiltOnHover),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform;

    Offset at(WidgetTester tester, double fx, double fy) {
      final rect = tester.getRect(find.byType(TiltOnHover));
      return Offset(rect.left + rect.width * fx, rect.top + rect.height * fy);
    }

    testWidgets('tanpa kursor: tegak', (tester) async {
      await pumpTilt(tester);
      expect(isUpright(matrix(tester)), isTrue);
    });

    testWidgets(
      'miring ke arah kursor, berlawanan di sisi lain, tegak lagi saat pergi',
      (tester) async {
        await pumpTilt(tester);
        final mouse = await newMouse(tester);

        await mouse.moveTo(at(tester, 0.05, 0.5));
        await tester.pumpAndSettle();
        final left = matrix(tester).entry(0, 2);
        expect(isUpright(matrix(tester)), isFalse);

        await mouse.moveTo(at(tester, 0.95, 0.5));
        await tester.pumpAndSettle();
        final right = matrix(tester).entry(0, 2);

        expect(left.abs(), greaterThan(0.01));
        expect(left.sign, isNot(right.sign));

        await mouse.moveTo(at(tester, 0.5, 0.05));
        await tester.pumpAndSettle();
        final top = matrix(tester).entry(1, 2);
        await mouse.moveTo(at(tester, 0.5, 0.95));
        await tester.pumpAndSettle();
        final bottom = matrix(tester).entry(1, 2);
        expect(top.sign, isNot(bottom.sign));

        await mouse.moveTo(const Offset(1, 1)); // keluar
        await tester.pumpAndSettle();
        expect(isUpright(matrix(tester)), isTrue);
      },
    );

    testWidgets('di tengah: hampir tegak', (tester) async {
      await pumpTilt(tester);
      final mouse = await newMouse(tester);

      await mouse.moveTo(at(tester, 0.5, 0.5));
      await tester.pumpAndSettle();

      expect(matrix(tester).entry(0, 2).abs(), lessThan(0.001));
      expect(matrix(tester).entry(1, 2).abs(), lessThan(0.001));
    });

    testWidgets('sentuhan jari tidak memiringkan', (tester) async {
      await pumpTilt(tester);

      final touch = await tester.startGesture(at(tester, 0.05, 0.05));
      await tester.pumpAndSettle();
      expect(isUpright(matrix(tester)), isTrue);
      await touch.up();
    });

    testWidgets('dinonaktifkan: tidak ada Transform sama sekali', (
      tester,
    ) async {
      await pumpTilt(tester, enabled: false);

      expect(
        find.descendant(
          of: find.byType(TiltOnHover),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });

    testWidgets('sudut maksimum dihormati', (tester) async {
      await tester.pumpWidget(
        app(
          const Center(
            child: TiltOnHover(
              maxAngle: 0.2,
              child: SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );
      final mouse = await newMouse(tester);

      await mouse.moveTo(at(tester, 0.99, 0.5));
      await tester.pumpAndSettle();

      expect(matrix(tester).entry(0, 2).abs(), lessThan(0.21));
      expect(matrix(tester).entry(0, 2).abs(), greaterThan(0.15));
    });
  });

  // ----------------------------------------------------------- ShineSweep
  group('ShineSweep', () {
    Widget sweep(bool active) => app(
      Scaffold(
        body: Center(
          child: ShineSweep(
            active: active,
            radius: 12,
            child: const SizedBox(width: 200, height: 50),
          ),
        ),
      ),
    );

    ShinePainter painter(WidgetTester tester) =>
        tester.widget<CustomPaint>(shine()).painter! as ShinePainter;

    testWidgets('menyapu saat active menjadi true, lalu hilang', (
      tester,
    ) async {
      await tester.pumpWidget(sweep(false));
      expect(shine(), findsNothing);

      await tester.pumpWidget(sweep(true));
      await tester.pump(const Duration(milliseconds: 250));
      final mid = painter(tester).progress;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));

      await tester.pump(const Duration(milliseconds: 200));
      expect(painter(tester).progress, greaterThan(mid)); // terus bergerak

      await tester.pump(ShineSweep.duration);
      await tester.pump();
      expect(shine(), findsNothing);
      await dispose(tester);
    });

    testWidgets('tetap active tidak mengulang; false lalu true menyapu lagi', (
      tester,
    ) async {
      await tester.pumpWidget(sweep(true));
      await tester.pump(ShineSweep.duration);
      await tester.pump();
      expect(shine(), findsNothing);

      await tester.pumpWidget(sweep(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(shine(), findsNothing); // tidak mengulang

      await tester.pumpWidget(sweep(false));
      await tester.pumpWidget(sweep(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(shine(), findsOneWidget);
      await tester.pump(ShineSweep.duration);
      await dispose(tester);
    });

    testWidgets('animasi mati: tidak ada kilau', (tester) async {
      UiConfig.animate = false;
      await tester.pumpWidget(sweep(false));
      await tester.pumpWidget(sweep(true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(shine(), findsNothing);
    });

    testWidgets('tidak menghalangi sentuhan', (tester) async {
      var taps = 0;
      final active = ValueNotifier(false);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (_, a, _) => ShineSweep(
                  active: a,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    key: const Key('target'),
                    onTap: () => taps++,
                    child: const SizedBox(width: 200, height: 50),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(); // transisi rute selesai

      active.value = true;
      await tester.pump(const Duration(milliseconds: 100));
      expect(shine(), findsOneWidget); // kilau sedang berjalan

      await tester.tap(find.byKey(const Key('target')));
      expect(taps, 1);
      await tester.pump(ShineSweep.duration);
      await dispose(tester);
    });

    testWidgets(
      'ShinePainter: posisi pita mengikuti progress dan hanya repaint bila berubah',
      (tester) async {
        expect(
          const ShinePainter(0.5).shouldRepaint(const ShinePainter(0.5)),
          isFalse,
        );
        expect(
          const ShinePainter(0.5).shouldRepaint(const ShinePainter(0.6)),
          isTrue,
        );
      },
    );

    group('pada PrimaryButton', () {
      Future<void> pumpButton(
        WidgetTester tester, {
        bool outline = false,
        VoidCallback? onPressed,
      }) => tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: PrimaryButton(
                  text: 'Bayar',
                  outline: outline,
                  onPressed: onPressed,
                ),
              ),
            ),
          ),
        ),
      );

      testWidgets('kilau menyapu saat kursor masuk, tidak saat keluar', (
        tester,
      ) async {
        await pumpButton(tester, onPressed: () {});
        final mouse = await newMouse(tester);
        expect(shine(), findsNothing);

        await mouse.moveTo(tester.getCenter(find.text('Bayar')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(shine(), findsOneWidget);

        await tester.pump(ShineSweep.duration);
        await tester.pump();
        expect(shine(), findsNothing);

        await mouse.moveTo(const Offset(1, 1));
        await tester.pump(const Duration(milliseconds: 100));
        expect(shine(), findsNothing);
        await dispose(tester);
      });

      testWidgets('tombol dinonaktifkan: tanpa kilau', (tester) async {
        await pumpButton(tester);
        final mouse = await newMouse(tester);

        await mouse.moveTo(tester.getCenter(find.text('Bayar')));
        await tester.pump(const Duration(milliseconds: 200));

        expect(shine(), findsNothing);
      });

      testWidgets('tombol bergaris luar: tanpa kilau', (tester) async {
        await pumpButton(tester, outline: true, onPressed: () {});
        final mouse = await newMouse(tester);

        await mouse.moveTo(tester.getCenter(find.text('Bayar')));
        await tester.pump(const Duration(milliseconds: 200));

        expect(shine(), findsNothing);
      });

      testWidgets('tombol tetap bisa diklik saat kilau berjalan', (
        tester,
      ) async {
        var taps = 0;
        await pumpButton(tester, onPressed: () => taps++);
        final mouse = await newMouse(tester);
        await mouse.moveTo(tester.getCenter(find.text('Bayar')));
        await tester.pump(const Duration(milliseconds: 150));

        await mouse.down(tester.getCenter(find.text('Bayar')));
        await mouse.up();
        await tester.pump();

        expect(taps, 1);
        await tester.pump(ShineSweep.duration);
        await dispose(tester);
      });
    });
  });

  // ---------------------------------------------------------- ProductCard
  group('Kartu produk: gambar membesar dan miring saat hover', () {
    Future<void> pumpCard(WidgetTester tester) => tester.pumpWidget(
      app(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: ProductCard.extent,
              child: ProductCard(product: store.products[0], onTap: () {}),
            ),
          ),
        ),
      ),
    );

    Iterable<double> scales(WidgetTester tester) => tester
        .widgetList<AnimatedScale>(
          find.descendant(
            of: find.byType(ProductCard),
            matching: find.byType(AnimatedScale),
          ),
        )
        .map((s) => s.scale);

    testWidgets('gambar membesar 1,08x dan kembali saat kursor pergi', (
      tester,
    ) async {
      await pumpCard(tester);
      final mouse = await newMouse(tester);
      expect(scales(tester), isNot(contains(1.08)));

      await mouse.moveTo(tester.getCenter(find.byType(ProductCard)));
      await tester.pumpAndSettle();
      expect(scales(tester), contains(1.08));

      await mouse.moveTo(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(scales(tester), isNot(contains(1.08)));
    });

    testWidgets('kartu miring mengikuti kursor lalu tegak lagi', (
      tester,
    ) async {
      await pumpCard(tester);
      final mouse = await newMouse(tester);
      Matrix4 tilt() => tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(TiltOnHover),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform;
      expect(isUpright(tilt()), isTrue);

      final rect = tester.getRect(find.byType(ProductCard));
      await mouse.moveTo(Offset(rect.left + 10, rect.top + 10));
      await tester.pumpAndSettle();
      expect(isUpright(tilt()), isFalse);

      await mouse.moveTo(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(isUpright(tilt()), isTrue);
    });

    testWidgets('kartu miring tetap bisa diklik di tengahnya', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: ProductCard.extent,
                child: ProductCard(
                  product: store.products[0],
                  onTap: () => opened++,
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await newMouse(tester);
      final rect = tester.getRect(find.byType(ProductCard));
      await mouse.moveTo(Offset(rect.left + 15, rect.top + 15));
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.text(store.products[0].name));
      await mouse.moveTo(center);
      await mouse.down(center);
      await mouse.up();
      await tester.pump();

      expect(opened, 1);
    });
  });

  // ---------------------------------------------------- Dashboard admin
  group('Dashboard admin', () {
    setUp(() {
      auth.logout();
    });

    testWidgets('angka statistik berhitung naik dari 0', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final total = '${store.products.length}';

      await tester.pumpWidget(app(const AdminDashboardPage()));
      // Frame pertama: semua angka masih 0.
      expect(find.text(total), findsNothing);
      expect(find.text('0'), findsWidgets);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(total), findsWidgets);
      await dispose(tester);
    });

    testWidgets('kartu muncul bergantian', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const AdminDashboardPage()));
      await tester.pump(const Duration(milliseconds: 120));

      final fades = find.byType(FadeSlideIn);
      expect(fades, findsAtLeastNWidgets(4));
      expect(
        opacityOf(tester, fades.at(0)),
        greaterThan(opacityOf(tester, fades.at(3))),
      );
      await tester.pump(const Duration(seconds: 2));
      await dispose(tester);
    });

    testWidgets('hover: kartu naik, bingkai dan bayangan berubah', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const AdminDashboardPage()));
      await tester.pump(const Duration(seconds: 2));

      final card = find.ancestor(
        of: find.text('Total Produk'),
        matching: find.byType(AnimatedContainer),
      );
      AnimatedContainer container() =>
          tester.widget<AnimatedContainer>(card.first);
      expect(container().transform!.getTranslation().y, 0);

      final before = container().decoration! as BoxDecoration;
      final mouse = await newMouse(tester);
      await mouse.moveTo(tester.getCenter(find.text('Total Produk')));
      await tester.pumpAndSettle();

      final after = container().decoration! as BoxDecoration;
      expect(container().transform!.getTranslation().y, -4);
      expect(after.boxShadow!.single.blurRadius, 22);
      expect(
        after.boxShadow!.single.blurRadius,
        greaterThan(before.boxShadow!.single.blurRadius),
      );

      await mouse.moveTo(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(container().transform!.getTranslation().y, 0);
    });
  });

  group('Laporan: total penjualan berhitung naik', () {
    testWidgets('mulai dari Rp 0 lalu mencapai total', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final total = formatRupiah(store.totalSales);
      expect(store.totalSales, greaterThan(0));

      await tester.pumpWidget(
        app(AdminReportsPage(now: DateTime(2026, 11, 16))),
      );
      expect(find.text(formatRupiah(0)), findsWidgets);
      expect(find.text(total), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(total), findsOneWidget);
      await dispose(tester);
    });
  });

  // ------------------------------------------------- Beranda dan menu bawah
  group('Beranda dan menu bawah', () {
    testWidgets('lingkaran kategori muncul bergantian dengan efek melompat', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const HomePage()));

      final pops = find.byType(PopIn);
      expect(pops, findsAtLeastNWidgets(3));
      expect(opacityOf(tester, pops.first), 0);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(opacityOf(tester, pops.first), 1);
      expect(opacityOf(tester, pops.at(2)), 1);
      await dispose(tester);
    });

    testWidgets('ikon menu yang dipilih melompat saat berpindah tab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const UserShell()));
      await tester.pump(const Duration(seconds: 2));

      Finder navPop() => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(PopIn),
      );
      expect(navPop(), findsOneWidget);
      expect(
        find.descendant(
          of: navPop(),
          matching: find.byIcon(Icons.home_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Kategori'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(navPop(), findsOneWidget);
      expect(
        find.descendant(
          of: navPop(),
          matching: find.byIcon(Icons.grid_view_rounded),
        ),
        findsOneWidget,
      );
      // Sedang melompat: belum penuh.
      expect(opacityOf(tester, navPop()), lessThan(1));

      await tester.pump(const Duration(seconds: 2));
      expect(opacityOf(tester, navPop()), 1);
      await dispose(tester);
    });
  });
}
