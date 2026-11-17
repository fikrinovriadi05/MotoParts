import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/pages/user/category_page.dart';
import 'package:motopart/pages/user/product_detail_page.dart';
import 'package:motopart/pages/user/product_image_viewer.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/category_circle.dart';
import 'package:motopart/widgets/hover.dart';
import 'package:motopart/widgets/hover_icon_circle.dart';
import 'package:motopart/widgets/press_scale.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/product_card.dart';

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

/// Mouse virtual yang bisa digerakkan ke atas widget (perangkat mouse berid 1).
Future<TestGesture> newMouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(1, 1));
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

MouseCursor? cursorNow() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);

void main() {
  setUp(() {
    final fresh = Store();
    store.products
      ..clear()
      ..addAll(fresh.products);
    store.setCurrentAccount(Store.guestId);
    store.cart.clear();
  });

  group('HoverBuilder', () {
    testWidgets('hovered berubah saat kursor masuk dan keluar', (tester) async {
      final states = <bool>[];
      await tester.pumpWidget(
        app(
          Center(
            child: HoverBuilder(
              builder: (context, hovered) {
                states.add(hovered);
                return const SizedBox(width: 100, height: 100);
              },
            ),
          ),
        ),
      );
      final mouse = await newMouse(tester);
      expect(states.last, isFalse);

      await mouse.moveTo(tester.getCenter(find.byType(HoverBuilder)));
      await tester.pump();
      expect(states.last, isTrue);
      expect(cursorNow(), SystemMouseCursors.click);

      await mouse.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(states.last, isFalse);
      expect(cursorNow(), isNot(SystemMouseCursors.click));
    });

    testWidgets(
      'dinonaktifkan: tidak ada efek hover dan kursor tidak berubah',
      (tester) async {
        var hovered = false;
        await tester.pumpWidget(
          app(
            Center(
              child: HoverBuilder(
                enabled: false,
                builder: (context, h) {
                  hovered = h;
                  return const SizedBox(width: 100, height: 100);
                },
              ),
            ),
          ),
        );
        final mouse = await newMouse(tester);

        await mouse.moveTo(tester.getCenter(find.byType(HoverBuilder)));
        await tester.pump();

        expect(hovered, isFalse);
        expect(cursorNow(), isNot(SystemMouseCursors.click));
      },
    );

    testWidgets('layar sentuh tidak pernah hovered', (tester) async {
      var hovered = false;
      await tester.pumpWidget(
        app(
          Center(
            child: HoverBuilder(
              builder: (context, h) {
                hovered = h;
                return const SizedBox(width: 100, height: 100);
              },
            ),
          ),
        ),
      );

      final touch = await tester.startGesture(
        tester.getCenter(find.byType(HoverBuilder)),
      );
      await tester.pump();
      await touch.up();
      await tester.pump();

      expect(hovered, isFalse);
    });
  });

  group('PressScale: hover dan tekan', () {
    Future<void> pumpScale(WidgetTester tester, {VoidCallback? onTap}) =>
        tester.pumpWidget(
          app(
            Center(
              child: PressScale(
                onTap: onTap,
                child: const SizedBox(width: 120, height: 120),
              ),
            ),
          ),
        );

    double scaleOf(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    testWidgets('membesar sedikit saat hover, kembali saat kursor pergi', (
      tester,
    ) async {
      await pumpScale(tester, onTap: () {});
      final mouse = await newMouse(tester);
      expect(scaleOf(tester), 1.0);

      await mouse.moveTo(tester.getCenter(find.byType(PressScale)));
      await tester.pump();
      expect(scaleOf(tester), 1.025);
      expect(cursorNow(), SystemMouseCursors.click);

      await mouse.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(scaleOf(tester), 1.0);
    });

    testWidgets(
      'ditekan saat hover: mengecil, dilepas: kembali ke ukuran hover',
      (tester) async {
        var taps = 0;
        await pumpScale(tester, onTap: () => taps++);
        final mouse = await newMouse(tester);
        await mouse.moveTo(tester.getCenter(find.byType(PressScale)));
        await tester.pump();

        await mouse.down(tester.getCenter(find.byType(PressScale)));
        await tester.pump();
        expect(scaleOf(tester), 0.97);

        await mouse.up();
        await tester.pump();
        expect(scaleOf(tester), 1.025);
        expect(taps, 1);
      },
    );

    testWidgets(
      'tanpa aksi (onTap kosong): tidak ada efek hover dan kursor biasa',
      (tester) async {
        await pumpScale(tester);
        final mouse = await newMouse(tester);

        await mouse.moveTo(tester.getCenter(find.byType(PressScale)));
        await tester.pump();

        expect(scaleOf(tester), 1.0);
        expect(cursorNow(), isNot(SystemMouseCursors.click));
      },
    );

    testWidgets('hoverScale 1 mematikan pembesaran', (tester) async {
      await tester.pumpWidget(
        app(
          Center(
            child: PressScale(
              onTap: () {},
              hoverScale: 1,
              child: const SizedBox(width: 120, height: 120),
            ),
          ),
        ),
      );
      final mouse = await newMouse(tester);

      await mouse.moveTo(tester.getCenter(find.byType(PressScale)));
      await tester.pump();

      expect(scaleOf(tester), 1.0);
    });
  });

  group('Tombol utama: hover', () {
    double scaleOf(WidgetTester tester) => tester
        .widget<AnimatedScale>(
          find.descendant(
            of: find.byType(PrimaryButton),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;

    for (final outline in [false, true]) {
      testWidgets('membesar sedikit saat hover (outline: $outline)', (
        tester,
      ) async {
        await tester.pumpWidget(
          app(
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: PrimaryButton(
                    text: 'Bayar',
                    outline: outline,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final mouse = await newMouse(tester);

        await mouse.moveTo(tester.getCenter(find.text('Bayar')));
        await tester.pump();
        expect(scaleOf(tester), 1.02);

        await mouse.moveTo(const Offset(1, 1));
        await tester.pump();
        expect(scaleOf(tester), 1.0);
      });
    }

    testWidgets('dinonaktifkan: tidak ada hover', (tester) async {
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: PrimaryButton(text: 'Bayar', onPressed: null),
              ),
            ),
          ),
        ),
      );
      final mouse = await newMouse(tester);

      await mouse.moveTo(tester.getCenter(find.text('Bayar')));
      await tester.pump();

      expect(scaleOf(tester), 1.0);
    });
  });

  group('Kartu produk dan kategori: hover', () {
    BoxDecoration cardDecoration(WidgetTester tester) {
      final box = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(ProductCard),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return box.decoration! as BoxDecoration;
    }

    testWidgets('kartu produk: bayangan terangkat dan bingkai berwarna utama', (
      tester,
    ) async {
      final product = store.products[0];
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: ProductCard.extent,
                child: ProductCard(product: product, onTap: () {}),
              ),
            ),
          ),
        ),
      );
      final mouse = await newMouse(tester);
      final normal = cardDecoration(tester);
      final normalShadow = normal.boxShadow!.single;

      await mouse.moveTo(tester.getCenter(find.byType(ProductCard)));
      await tester.pump();
      final hovered = cardDecoration(tester);
      final hoveredShadow = hovered.boxShadow!.single;

      expect(hoveredShadow.blurRadius, greaterThan(normalShadow.blurRadius));
      expect(hoveredShadow.offset.dy, greaterThan(normalShadow.offset.dy));
      expect(
        (hovered.border! as Border).top.color,
        isNot(normal.border!.toString()),
      );
      expect(
        (hovered.border! as Border).top.color.a,
        lessThan(1),
        reason: 'warna utama transparan sebagian',
      );
      expect(cursorNow(), SystemMouseCursors.click);

      await mouse.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(
        cardDecoration(tester).boxShadow!.single.blurRadius,
        normalShadow.blurRadius,
      );
    });

    testWidgets('kartu produk tetap bisa dibuka dengan klik mouse', (
      tester,
    ) async {
      final product = store.products[0];
      var opened = 0;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: ProductCard.extent,
                child: ProductCard(product: product, onTap: () => opened++),
              ),
            ),
          ),
        ),
      );
      final mouse = await newMouse(tester);
      await mouse.moveTo(tester.getCenter(find.text(product.name)));
      await mouse.down(tester.getCenter(find.text(product.name)));
      await mouse.up();
      await tester.pump();

      expect(opened, 1);
    });

    testWidgets(
      'lingkaran kategori: terisi warna utama dan bersinar saat hover',
      (tester) async {
        await tester.pumpWidget(
          app(
            Scaffold(
              body: Center(
                child: CategoryCircle(
                  title: 'Rem',
                  icon: Icons.disc_full_rounded,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        BoxDecoration circle() =>
            tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: find.byType(CategoryCircle),
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration!
                as BoxDecoration;
        final mouse = await newMouse(tester);
        final before = circle();

        await mouse.moveTo(tester.getCenter(find.byType(CategoryCircle)));
        await tester.pump();
        final after = circle();

        expect(after.color, isNot(before.color));
        expect(
          after.boxShadow!.single.blurRadius,
          greaterThan(before.boxShadow!.single.blurRadius),
        );
        expect(cursorNow(), SystemMouseCursors.click);
      },
    );
  });

  group('Gambar produk di detail: kursor zoom', () {
    testWidgets('detail: kursor pembesar; pembesar: kursor genggam', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final product = store.products[0];
      await tester.pumpWidget(app(ProductDetailPage(product: product)));
      final mouse = await newMouse(tester);

      await mouse.moveTo(tester.getCenter(find.byType(ProductImage)));
      await tester.pump();
      expect(cursorNow(), SystemMouseCursors.zoomIn);

      await tester.tap(find.byType(ProductImage));
      await tester.pumpAndSettle();
      await mouse.moveTo(const Offset(400, 1000));
      await tester.pump();

      expect(find.byType(ProductImageViewer), findsOneWidget);
      expect(cursorNow(), SystemMouseCursors.grab);
    });
  });

  group('Lingkaran ikon kategori: reaksi hover yang jelas', () {
    Widget circle({bool outlined = true}) => app(
      Scaffold(
        body: Center(
          child: HoverBuilder(
            builder: (context, hovered) => HoverIconCircle(
              icon: Icons.settings_rounded,
              hovered: hovered,
              outlined: outlined,
            ),
          ),
        ),
      ),
    );

    BoxDecoration decorationOf(WidgetTester tester) =>
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byType(HoverIconCircle),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;

    Color? iconColor(WidgetTester tester) =>
        tester.widget<Icon>(find.byType(Icon)).color;

    double scaleOf(WidgetTester tester) => tester
        .widget<AnimatedScale>(
          find.descendant(
            of: find.byType(HoverIconCircle),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;

    for (final outlined in [true, false]) {
      testWidgets(
        'terisi oranye penuh, ikon berwarna kontras, membesar, dan bersinar '
        '(outlined: $outlined)',
        (tester) async {
          await tester.pumpWidget(circle(outlined: outlined));
          await tester.pumpAndSettle();
          final mouse = await newMouse(tester);
          final before = decorationOf(tester);
          final iconBefore = iconColor(tester);
          expect(scaleOf(tester), 1.0);
          expect(before.color, isNot(AppColors.primary));

          await mouse.moveTo(tester.getCenter(find.byType(HoverIconCircle)));
          await tester.pumpAndSettle();

          final after = decorationOf(tester);
          expect(after.color, AppColors.primary);
          expect(iconColor(tester), AppColors.onPrimary);
          expect(iconColor(tester), isNot(iconBefore));
          expect(scaleOf(tester), 1.1);
          expect(
            after.boxShadow!.single.blurRadius,
            greaterThan(before.boxShadow!.single.blurRadius),
          );
          expect(after.boxShadow!.single.color.a, greaterThan(0.3));

          await mouse.moveTo(const Offset(1, 1));
          await tester.pumpAndSettle();
          expect(decorationOf(tester).color, before.color);
          expect(iconColor(tester), iconBefore);
          expect(scaleOf(tester), 1.0);
        },
      );
    }

    testWidgets(
      'lingkaran di Beranda (CategoryCircle) memakai reaksi yang sama',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          app(
            Scaffold(
              body: Center(
                child: CategoryCircle(
                  title: 'Rem',
                  icon: Icons.disc_full_rounded,
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        );
        final mouse = await newMouse(tester);

        await mouse.moveTo(tester.getCenter(find.byType(CategoryCircle)));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: find.byType(HoverIconCircle),
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration!,
          isA<BoxDecoration>().having(
            (d) => d.color,
            'color',
            AppColors.primary,
          ),
        );

        await mouse.down(tester.getCenter(find.byType(CategoryCircle)));
        await mouse.up();
        await tester.pump();
        expect(taps, 1);
      },
    );

    testWidgets(
      'halaman Kategori: kartu terangkat dan lingkaran ikon terisi saat hover',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app(const CategoryPage()));
        await tester.pumpAndSettle();
        final mouse = await newMouse(tester);

        final first = find.byType(HoverIconCircle).first;
        BoxDecoration circleDecoration() =>
            tester
                    .widget<AnimatedContainer>(
                      find
                          .descendant(
                            of: first,
                            matching: find.byType(AnimatedContainer),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        final before = circleDecoration();
        expect(before.color, isNot(AppColors.primary));

        await mouse.moveTo(tester.getCenter(first));
        await tester.pumpAndSettle();

        expect(circleDecoration().color, AppColors.primary);
        // Kartu: bingkai oranye dan bayangan terangkat.
        final card = tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.borderRadius != null);
        expect(card.boxShadow!.single.blurRadius, 22);
        expect((card.border! as Border).top.width, 1.6);
        expect(cursorNow(), SystemMouseCursors.click);

        // Kartu lain tidak ikut bereaksi.
        final second = find.byType(HoverIconCircle).at(1);
        final secondColor =
            (tester
                        .widget<AnimatedContainer>(
                          find
                              .descendant(
                                of: second,
                                matching: find.byType(AnimatedContainer),
                              )
                              .first,
                        )
                        .decoration!
                    as BoxDecoration)
                .color;
        expect(secondColor, isNot(AppColors.primary));
      },
    );
  });
}
