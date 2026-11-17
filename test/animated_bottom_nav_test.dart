import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_accent.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/theme/theme_controller.dart';
import 'package:motopart/widgets/animated_bottom_nav.dart';

const _items = [
  BottomNavItem(
    label: 'Beranda',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  ),
  BottomNavItem(
    label: 'Kategori',
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view_rounded,
  ),
  BottomNavItem(
    label: 'Keranjang',
    icon: Icons.shopping_bag_outlined,
    activeIcon: Icons.shopping_bag_rounded,
  ),
  BottomNavItem(
    label: 'Akun',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
  ),
];

/// Bilah yang mengelola indeksnya sendiri, untuk menguji komponen terpisah.
class _Host extends StatefulWidget {
  final ValueChanged<int>? onChanged;

  const _Host({this.onChanged});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('halaman $index')),
      bottomNavigationBar: AnimatedBottomNav(
        selectedIndex: index,
        items: _items,
        onSelected: (i) {
          setState(() => index = i);
          widget.onChanged?.call(i);
        },
      ),
    );
  }
}

Widget app(
  Widget home, {
  ThemeMode mode = ThemeMode.light,
  double scale = 1,
  EdgeInsets padding = EdgeInsets.zero,
}) => MaterialApp(
  theme: AppTheme.light(accent: themeController.accent.value),
  darkTheme: AppTheme.dark(accent: themeController.accent.value),
  themeMode: mode,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      padding: padding,
      viewPadding: padding,
    ),
    child: child!,
  ),
  home: home,
);

void size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder indicator() => find.byKey(const ValueKey('nav-indicator'));

Finder label(String text) => find.descendant(
  of: find.byType(AnimatedBottomNav),
  matching: find.text(text),
);

void main() {
  late bool animate;

  setUp(() {
    animate = UiConfig.animate;
    themeController.setAccent(AppAccent.orange);
  });

  tearDown(() {
    UiConfig.animate = animate;
    themeController.setAccent(AppAccent.orange);
    userTabIndex.value = UserTab.home;
  });

  group('geometri', () {
    test('lingkaran berada di tengah tiap menu', () {
      // Lebar 400, 4 menu: tiap slot 100, lingkaran 52.
      expect(AnimatedBottomNav.indicatorLeft(0, 400, 4), 24);
      expect(AnimatedBottomNav.indicatorLeft(1, 400, 4), 124);
      expect(AnimatedBottomNav.indicatorLeft(3, 400, 4), 324);
      for (var i = 0; i < 4; i++) {
        final center =
            AnimatedBottomNav.indicatorLeft(i, 400, 4) +
            AnimatedBottomNav.indicatorSize / 2;
        expect(center, 100 * i + 50);
      }
    });

    test('lingkaran tidak menabrak label', () {
      // Lingkaran: top 8 .. 60. Label: 6 dari dasar, tinggi ~13.
      const circleBottom = 8 + AnimatedBottomNav.indicatorSize;
      const labelTop =
          AnimatedBottomNav.totalHeight -
          AnimatedBottomNav.labelBottom -
          11 * 1.2;
      expect(circleBottom, lessThan(labelTop));
    });
  });

  group('tampilan', () {
    testWidgets('empat menu dengan label tetap tampil', (tester) async {
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));
      for (final text in ['Beranda', 'Kategori', 'Keranjang', 'Akun']) {
        expect(label(text), findsOneWidget);
      }
      expect(indicator(), findsOneWidget);
    });

    testWidgets('lingkaran berwarna aksen dan membulat sempurna', (
      tester,
    ) async {
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));

      final box = tester.getSize(indicator());
      expect(box.width, AnimatedBottomNav.indicatorSize);
      expect(box.height, AnimatedBottomNav.indicatorSize);

      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: indicator(),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      final colors = (decoration.gradient! as LinearGradient).colors;
      expect(colors.last, AppAccent.orange.color);
    });

    testWidgets('lingkaran mengikuti warna aksen yang dipilih', (tester) async {
      themeController.setAccent(AppAccent.blue);
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: indicator(),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(
        (decoration.gradient! as LinearGradient).colors.last,
        AppAccent.blue.color,
      );
    });

    testWidgets('menu aktif: ikon terisi, membesar, dan terangkat', (
      tester,
    ) async {
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsNothing);
      expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);

      final homeY = tester.getCenter(find.byIcon(Icons.home_rounded)).dy;
      final gridY = tester.getCenter(find.byIcon(Icons.grid_view_outlined)).dy;
      expect(homeY, lessThan(gridY), reason: 'ikon aktif terangkat');

      final scale = tester.widget<AnimatedScale>(
        find.ancestor(
          of: find.byIcon(Icons.home_rounded),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scale.scale, greaterThan(1));
      final other = tester.widget<AnimatedScale>(
        find.ancestor(
          of: find.byIcon(Icons.grid_view_outlined),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(other.scale, 1);
    });

    testWidgets('ikon aktif berada di dalam lingkaran, ikon lain abu-abu', (
      tester,
    ) async {
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));
      await tester.pumpAndSettle();

      final circle = tester.getRect(indicator());
      expect(
        circle.contains(tester.getCenter(find.byIcon(Icons.home_rounded))),
        isTrue,
      );

      Color? colorOf(IconData icon) =>
          tester.widget<Icon>(find.byIcon(icon)).color;
      final context = tester.element(find.byType(AnimatedBottomNav));
      // Warna ikon datang dari IconTheme beranimasi.
      Color? themed(IconData icon) =>
          IconTheme.of(tester.element(find.byIcon(icon))).color;
      expect(colorOf(Icons.home_rounded), isNull);
      expect(themed(Icons.home_rounded), context.palette.onAccent);
      expect(themed(Icons.grid_view_outlined), context.palette.textMuted);
      expect(themed(Icons.person_outline_rounded), context.palette.textMuted);
    });

    testWidgets('label aktif tebal berwarna aksen, lainnya abu-abu', (
      tester,
    ) async {
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AnimatedBottomNav));

      TextStyle style(String text) => tester
          .widget<AnimatedDefaultTextStyle>(
            find
                .ancestor(
                  of: label(text),
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first,
          )
          .style;
      expect(style('Beranda').fontWeight, FontWeight.w800);
      expect(style('Beranda').color, context.palette.primaryText);
      expect(style('Kategori').fontWeight, FontWeight.w500);
      expect(style('Kategori').color, context.palette.textMuted);
    });

    testWidgets('latar putih di mode terang, gelap di mode gelap', (
      tester,
    ) async {
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));
      Color barColor() {
        final box = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(AnimatedBottomNav),
                matching: find.byType(DecoratedBox),
              ),
            )
            .firstWhere(
              (d) => (d.decoration as BoxDecoration).borderRadius != null,
            );
        return (box.decoration as BoxDecoration).color!;
      }

      final light = barColor();
      expect(light.a, closeTo(0.96, 0.01)); // sedikit transparan
      expect((light.r * 255).round(), 255); // putih

      await tester.pumpWidget(app(const _Host(), mode: ThemeMode.dark));
      await tester.pumpAndSettle();
      expect((barColor().r * 255).round(), lessThan(80));
    });

    testWidgets('tinggi tetap + area aman bawah; tidak menutupi konten', (
      tester,
    ) async {
      size(tester, 400, 800);
      await tester.pumpWidget(
        app(const _Host(), padding: const EdgeInsets.only(bottom: 34)),
      );
      final nav = tester.getRect(find.byType(AnimatedBottomNav));
      expect(nav.bottom, 800, reason: 'menempel di dasar layar');
      expect(nav.height, AnimatedBottomNav.totalHeight + 34);

      // Konten halaman berakhir di atas bilah.
      final body = tester.getRect(find.text('halaman 0'));
      expect(body.bottom, lessThanOrEqualTo(nav.top));

      // Label tidak masuk ke area aman (gestur sistem).
      expect(
        tester.getRect(label('Beranda')).bottom,
        lessThanOrEqualTo(800 - 34),
      );
    });

    testWidgets('layar lebar: menu dibatasi lebarnya, latar penuh', (
      tester,
    ) async {
      size(tester, 1100, 800);
      await tester.pumpWidget(app(const _Host()));
      final first = tester.getCenter(label('Beranda')).dx;
      final last = tester.getCenter(label('Akun')).dx;
      expect(
        last - first,
        lessThanOrEqualTo(AnimatedBottomNav.maxContentWidth),
      );
      expect(tester.getSize(find.byType(AnimatedBottomNav)).width, 1100);
    });
  });

  group('interaksi dan animasi', () {
    testWidgets('lingkaran berpindah ke tiap menu yang ditekan', (
      tester,
    ) async {
      size(tester, 400, 800);
      var last = -1;
      await tester.pumpWidget(app(_Host(onChanged: (i) => last = i)));
      await tester.pumpAndSettle();

      for (final entry in {
        'Kategori': 1,
        'Keranjang': 2,
        'Akun': 3,
        'Beranda': 0,
      }.entries) {
        await tester.tap(label(entry.key));
        await tester.pumpAndSettle();
        expect(last, entry.value);
        expect(find.text('halaman ${entry.value}'), findsOneWidget);
        // Lingkaran tepat di atas ikon menu itu.
        final circle = tester.getCenter(indicator()).dx;
        final text = tester.getCenter(label(entry.key)).dx;
        expect(circle, closeTo(text, 0.6));
      }
    });

    testWidgets('berpindah dianimasikan: bergeser mendatar secara bertahap', (
      tester,
    ) async {
      UiConfig.animate = true;
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));
      await tester.pumpAndSettle();
      final xs = <double>[tester.getCenter(indicator()).dx];
      final y = tester.getCenter(indicator()).dy;

      await tester.tap(label('Akun'));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        xs.add(tester.getCenter(indicator()).dx);
      }
      await tester.pumpAndSettle();
      xs.add(tester.getCenter(indicator()).dx);

      // Bergerak ke kanan terus (boleh sedikit melampaui tujuan: efek pegas).
      expect(xs[1], greaterThan(xs[0]));
      expect(xs[2], greaterThan(xs[1]));
      expect(xs.last, closeTo(350, 0.6));
      expect(
        tester.getCenter(indicator()).dy,
        y,
        reason: 'tidak bergeser tegak',
      );
    });

    testWidgets('ikon naik/turun saat pilihan berpindah', (tester) async {
      UiConfig.animate = true;
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));
      await tester.pumpAndSettle();
      final before = tester.getCenter(find.byIcon(Icons.grid_view_outlined)).dy;

      await tester.tap(label('Kategori'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final mid = tester.getCenter(find.byIcon(Icons.grid_view_rounded)).dy;
      await tester.pumpAndSettle();
      final after = tester.getCenter(find.byIcon(Icons.grid_view_rounded)).dy;

      expect(after, lessThan(before));
      expect(mid, greaterThan(after), reason: 'sedang naik');
    });

    testWidgets('menekan menu yang sama tidak mengubah apa pun', (
      tester,
    ) async {
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));
      await tester.pumpAndSettle();
      final x = tester.getCenter(indicator()).dx;
      await tester.tap(label('Beranda'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(indicator()).dx, x);
    });

    testWidgets('area sentuh tiap menu minimal 48x48', (tester) async {
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));
      for (final text in ['Beranda', 'Kategori', 'Keranjang', 'Akun']) {
        final box = tester.getSize(
          find
              .ancestor(of: label(text), matching: find.byType(InkResponse))
              .first,
        );
        expect(box.width, greaterThanOrEqualTo(48));
        expect(box.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('semantik: tombol dengan status terpilih', (tester) async {
      final handle = tester.ensureSemantics();
      size(tester, 400, 800);
      await tester.pumpWidget(app(const _Host()));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Beranda')),
        isSemantics(
          label: 'Beranda',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('di aplikasi pembeli (UserShell)', () {
    Future<void> pumpShell(WidgetTester tester) async {
      size(tester, 400, 1800);
      await tester.pumpWidget(app(const UserShell()));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('menekan tiap menu mengganti halaman dan lingkaran', (
      tester,
    ) async {
      await pumpShell(tester);
      expect(userTabIndex.value, UserTab.home);

      await tester.tap(label('Kategori'));
      await tester.pumpAndSettle();
      expect(userTabIndex.value, UserTab.category);
      expect(
        tester.getCenter(indicator()).dx,
        closeTo(tester.getCenter(label('Kategori')).dx, 0.6),
      );

      await tester.tap(label('Keranjang'));
      await tester.pumpAndSettle();
      expect(userTabIndex.value, UserTab.cart);
      expect(find.text('Keranjang masih kosong'), findsOneWidget);

      await tester.tap(label('Akun'));
      await tester.pumpAndSettle();
      expect(userTabIndex.value, UserTab.account);

      await tester.tap(label('Beranda'));
      await tester.pumpAndSettle();
      expect(userTabIndex.value, UserTab.home);
    });

    testWidgets('lingkaran ikut saat tab diganti dari tempat lain', (
      tester,
    ) async {
      await pumpShell(tester);
      userTabIndex.value = UserTab.cart;
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(indicator()).dx,
        closeTo(tester.getCenter(label('Keranjang')).dx, 0.6),
      );
    });

    testWidgets('badge keranjang tetap tampil di ikon', (tester) async {
      await pumpShell(tester);
      store.addToCart(store.products[0]);
      store.addToCart(store.products[1]);
      await tester.pumpAndSettle();
      expect(find.byType(Badge), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('2')),
        findsWidgets,
      );
      store.cart.clear();
      store.notifyListeners();
    });

    for (final dark in [false, true]) {
      testWidgets(
        'bilah saja: tanpa overflow di 320, teks x1.6 (${dark ? 'gelap' : 'terang'})',
        (tester) async {
          size(tester, 320, 640);
          await tester.pumpWidget(
            app(
              const _Host(),
              mode: dark ? ThemeMode.dark : ThemeMode.light,
              scale: 1.6,
            ),
          );
          await tester.pumpAndSettle();
          for (final text in ['Kategori', 'Keranjang', 'Akun', 'Beranda']) {
            await tester.tap(label(text));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          'tanpa overflow di layar 320 (${dark ? 'gelap' : 'terang'}, teks x$scale)',
          (tester) async {
            size(tester, 320, 640);
            await tester.pumpWidget(
              app(
                const UserShell(),
                mode: dark ? ThemeMode.dark : ThemeMode.light,
                scale: scale,
              ),
            );
            await tester.pump(const Duration(seconds: 1));
            // Catatan: kartu halaman Kategori sudah lebih dulu meluap 24 px di
            // 320 dengan teks diperbesar (bukan dari bilah ini), jadi tab itu
            // hanya dibuka pada ukuran teks normal.
            final tabs = [
              if (scale == 1.0) 'Kategori',
              'Keranjang',
              'Akun',
              'Beranda',
            ];
            for (final text in tabs) {
              await tester.tap(label(text));
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
