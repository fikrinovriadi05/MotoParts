import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/motor_matching.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/user/catalog_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';

Product product(String type, {String name = 'Produk'}) => Product(
  id: 1,
  name: name,
  category: 'Mesin',
  type: type,
  price: 10000,
  stock: 5,
  icon: Icons.build_rounded,
  description: '-',
);

MotorFit fit(String type, String motor) =>
    MotorMatcher.fit(product(type), motor);

void main() {
  group('MotorMatcher: khusus motor tertentu', () {
    test('nama lengkap, sebagian, huruf besar/kecil, dan tanda baca', () {
      for (final motor in [
        'Honda Beat',
        'Beat',
        'beat',
        'BEAT',
        '  honda   beat ',
        'honda-beat',
        'motor Honda Beat',
        'Honda Beat Street', // varian ikut diketik
        'Honda',
      ]) {
        expect(fit('Honda Beat', motor), MotorFit.exact, reason: motor);
      }
    });

    test('motor lain tidak cocok', () {
      for (final motor in ['Honda Vario', 'Yamaha Mio', 'Supra X', 'Suzuki']) {
        expect(fit('Honda Beat', motor), MotorFit.none, reason: motor);
      }
    });

    test(
      'beberapa motor dalam satu produk (koma, titik koma, garis miring)',
      () {
        for (final type in [
          'Honda Beat, Honda Vario, Yamaha Mio',
          'Honda Beat; Honda Vario; Yamaha Mio',
          'Honda Beat / Honda Vario / Yamaha Mio',
        ]) {
          expect(fit(type, 'Vario'), MotorFit.exact, reason: type);
          expect(fit(type, 'Yamaha Mio'), MotorFit.exact, reason: type);
          expect(fit(type, 'Honda Mio'), MotorFit.none, reason: type);
          expect(fit(type, 'Scoopy'), MotorFit.none, reason: type);
        }
      },
    );

    test('nama dengan spasi: Supra X', () {
      expect(fit('Honda Supra X', 'Supra X'), MotorFit.exact);
      expect(fit('Honda Supra X', 'Honda Supra X'), MotorFit.exact);
      expect(fit('Honda Supra X', 'supra'), MotorFit.exact);
      expect(fit('Honda Supra X', 'Honda Beat'), MotorFit.none);
    });

    test('pencarian kosong: semua dianggap cocok', () {
      expect(fit('Honda Beat', ''), MotorFit.exact);
      expect(fit('Universal', '   '), MotorFit.exact);
      expect(MotorMatcher.matches(product('Honda Beat'), ''), isTrue);
    });
  });

  group('MotorMatcher: sejenis (jenis motor)', () {
    test('"Honda Matic" cocok dengan motor matic Honda', () {
      for (final motor in [
        'Honda Beat',
        'Beat',
        'Honda Vario',
        'Scoopy',
        'honda pcx',
      ]) {
        expect(fit('Honda Matic', motor), MotorFit.group, reason: motor);
      }
    });

    test('merek berbeda atau jenis berbeda tidak cocok', () {
      expect(fit('Honda Matic', 'Yamaha Mio'), MotorFit.none);
      expect(fit('Honda Matic', 'Yamaha NMAX'), MotorFit.none);
      expect(fit('Honda Matic', 'Honda Supra X'), MotorFit.none); // bebek
      expect(fit('Honda Matic', 'Honda CB150R'), MotorFit.none); // sport
    });

    test('tanpa merek: berlaku untuk semua merek pada jenis itu', () {
      expect(fit('Matic', 'Yamaha Mio'), MotorFit.group);
      expect(fit('Skutik', 'Honda Beat'), MotorFit.group);
      expect(fit('Bebek', 'Honda Supra X'), MotorFit.group);
      expect(fit('Bebek', 'Yamaha Jupiter'), MotorFit.group);
      expect(fit('Sport', 'Kawasaki Ninja'), MotorFit.group);
      expect(fit('Sport', 'Honda Beat'), MotorFit.none);
    });

    test('jenis diketik langsung', () {
      expect(fit('Honda Matic', 'Honda Matic'), MotorFit.group);
      expect(fit('Honda Matic', 'Matic'), MotorFit.group);
      expect(fit('Honda Matic', 'Honda'), MotorFit.group);
      expect(fit('Honda Matic', 'Yamaha Matic'), MotorFit.none);
    });

    test('model yang tidak dikenal tidak ditebak', () {
      expect(fit('Honda Matic', 'Honda Xyz'), MotorFit.none);
    });
  });

  group('MotorMatcher: universal', () {
    test(
      'Universal, Berbagai tipe, dan sejenisnya cocok dengan semua motor',
      () {
        for (final type in [
          'Universal',
          'universal',
          'Berbagai tipe',
          'Semua motor',
          '',
        ]) {
          expect(fit(type, 'Honda Beat'), MotorFit.universal, reason: type);
          expect(fit(type, 'Yamaha NMAX'), MotorFit.universal, reason: type);
          expect(MotorMatcher.isUniversal(product(type)), isTrue, reason: type);
        }
      },
    );

    test('includeUniversal mengatur apakah produk universal ikut', () {
      final p = product('Universal');
      expect(MotorMatcher.matches(p, 'Honda Beat'), isTrue);
      expect(
        MotorMatcher.matches(p, 'Honda Beat', includeUniversal: false),
        isFalse,
      );
      // Produk khusus tidak terpengaruh.
      final beat = product('Honda Beat');
      expect(
        MotorMatcher.matches(beat, 'Honda Beat', includeUniversal: false),
        isTrue,
      );
    });

    test('produk universal sekaligus khusus: yang khusus menang', () {
      expect(fit('Universal, Honda Beat', 'Honda Beat'), MotorFit.exact);
      expect(fit('Universal, Honda Beat', 'Yamaha Mio'), MotorFit.universal);
    });

    test('produk motor tertentu bukan universal', () {
      expect(MotorMatcher.isUniversal(product('Honda Beat')), isFalse);
      expect(MotorMatcher.isUniversal(product('Honda Matic')), isFalse);
    });

    test('urutan kecocokan: khusus < sejenis < universal < tidak cocok', () {
      expect(MotorFit.exact.index, lessThan(MotorFit.group.index));
      expect(MotorFit.group.index, lessThan(MotorFit.universal.index));
      expect(MotorFit.universal.index, lessThan(MotorFit.none.index));
    });
  });

  group('MotorMatcher.knownMotors', () {
    test('daftar motor dari produk: tanpa universal, tanpa jenis, tanpa duplikat, urut', () {
      final motors = MotorMatcher.knownMotors(Store().products);

      expect(motors, contains('Honda Beat'));
      expect(motors, contains('Honda Vario'));
      expect(motors, contains('Honda Supra X'));
      expect(motors, contains('Yamaha Mio'));
      expect(motors, isNot(contains('Universal')));
      expect(motors, isNot(contains('Berbagai tipe')));
      expect(motors, isNot(contains('Honda Matic')));
      expect(motors.toSet().length, motors.length);
      final sorted = [...motors]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      expect(motors, sorted);
    });

    test('duplikat beda huruf/spasi digabung', () {
      final motors = MotorMatcher.knownMotors([
        product('Honda Beat'),
        product('honda  beat'),
        product('HONDA-BEAT, Yamaha Mio'),
      ]);
      expect(motors.length, 2);
    });
  });

  group('Store.searchProducts dengan filter motor', () {
    late Store s;
    setUp(() => s = Store());

    Set<String> names(List<Product> list) => {for (final p in list) p.name};

    test('Honda Beat: khusus, sejenis, dan universal; yang lain tidak', () {
      final result = s.searchProducts(motor: 'Honda Beat');

      expect(
        names(result),
        containsAll([
          'Kampas Rem Depan', // Honda Beat
          'Oli Mesin Matic 0,8 L', // Beat, Vario, Mio
          'Ban Luar 80/90-14',
          'Ban Dalam 80/90-14',
          'Oli Gardan 120 ml', // Honda Matic (sejenis)
          'Busi NGK', // Universal
          'Oli Mesin 10W-40', // Berbagai tipe
        ]),
      );
      expect(names(result), isNot(contains('Filter Oli Honda'))); // Vario
      expect(names(result), isNot(contains('Gear Set'))); // Supra X
    });

    test('urutan: khusus dulu, lalu sejenis, lalu universal (urutan daftar dipertahankan)', () {
      final result = s.searchProducts(motor: 'Honda Beat');
      final fits = [for (final p in result) MotorMatcher.fit(p, 'Honda Beat')];

      final sorted = [...fits]..sort((a, b) => a.index.compareTo(b.index));
      expect(fits, sorted);
      expect(fits.first, MotorFit.exact);
      expect(fits.last, MotorFit.universal);

      // Di dalam kelompok yang sama, urutan asli daftar produk tetap.
      final exact = [
        for (final p in result)
          if (MotorMatcher.fit(p, 'Honda Beat') == MotorFit.exact)
            s.products.indexOf(p),
      ];
      final exactSorted = [...exact]..sort();
      expect(exact, exactSorted);
    });

    test('tanpa produk universal', () {
      final result = s.searchProducts(
        motor: 'Honda Beat',
        includeUniversal: false,
      );

      expect(names(result), isNot(contains('Busi NGK')));
      expect(names(result), isNot(contains('Oli Mesin 10W-40')));
      expect(names(result), contains('Kampas Rem Depan'));
      expect(names(result), contains('Oli Gardan 120 ml'));
    });

    test(
      'Yamaha Mio: hanya yang menyebut Mio, plus sejenis Yamaha dan universal',
      () {
        final result = s.searchProducts(
          motor: 'Yamaha Mio',
          includeUniversal: false,
        );

        expect(names(result), {'Oli Mesin Matic 0,8 L'});
      },
    );

    test('digabung dengan kategori, kata kunci, dan harga', () {
      final oli = s.searchProducts(category: 'Oli', motor: 'Honda Beat');
      expect(oli.every((p) => p.category == 'Oli'), isTrue);
      expect(names(oli), contains('Oli Gardan 120 ml'));

      expect(
        names(
          s.searchProducts(
            keyword: 'ban',
            motor: 'Honda Beat',
            includeUniversal: false,
          ),
        ),
        {'Ban Luar 80/90-14', 'Ban Dalam 80/90-14'},
      );

      final cheap = s.searchProducts(motor: 'Honda Beat', maxPrice: 30000);
      expect(cheap.every((p) => p.price <= 30000), isTrue);
    });

    test('motor tidak dikenal: kosong tanpa universal, universal saja dengan universal', () {
      expect(
        s.searchProducts(motor: 'Yamaha NMAX', includeUniversal: false),
        isEmpty,
      );
      final onlyUniversal = s.searchProducts(motor: 'Yamaha NMAX');
      expect(onlyUniversal, isNotEmpty);
      expect(onlyUniversal.every(MotorMatcher.isUniversal), isTrue);
    });

    test('motor kosong atau spasi: semua produk, urutan bawaan', () {
      expect(s.searchProducts(motor: '').length, s.products.length);
      expect(
        s.searchProducts(motor: '   ').map((p) => p.id),
        s.products.map((p) => p.id),
      );
    });

    test('urutan harga mengalahkan urutan kecocokan', () {
      final result = s.searchProducts(
        motor: 'Honda Beat',
        sort: ProductSort.priceLowToHigh,
      );
      final prices = [for (final p in result) p.price];
      final sorted = [...prices]..sort();
      expect(prices, sorted);
    });
  });

  group('CatalogPage: filter tipe motor', () {
    setUp(() {
      final fresh = Store();
      store.products
        ..clear()
        ..addAll(fresh.products);
      auth.logout();
      auth.accounts.removeWhere((a) => !a.isAdmin);
      store.setCurrentAccount(Store.guestId);
    });
    tearDown(() {
      auth.logout();
      auth.accounts.removeWhere((a) => !a.isAdmin);
    });

    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> pump(WidgetTester tester, {String? initialMotor}) async {
      bigScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: CatalogPage(initialMotor: initialMotor),
        ),
      );
    }

    Future<void> chooseMotor(WidgetTester tester, String motor) async {
      await tester.tap(find.text('Pilih tipe motor'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, motor));
      await tester.pumpAndSettle();
    }

    void login({bool withMotor = false}) {
      auth.register(
        name: 'Siti',
        email: 'siti-motor@email.com',
        phone: '081234567890',
        password: 'rahasia1',
      );
      auth.login(
        email: 'siti-motor@email.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );
      if (withMotor) {
        auth.updateProfile(
          name: 'Siti',
          phone: '081234567890',
          motorName: 'Honda Beat',
          motorType: 'Street',
          motorYear: '2020',
        );
      }
    }

    testWidgets('awal: semua produk dan tombol Pilih tipe motor', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Pilih tipe motor'), findsOneWidget);
      expect(find.textContaining('sparepart cocok untuk'), findsNothing);
      expect(find.text('Gear Set'), findsOneWidget);
      expect(find.text('Filter Oli Honda'), findsOneWidget);
    });

    testWidgets(
      'memilih motor dari saran menyaring produk dan menampilkan jumlahnya',
      (tester) async {
        await pump(tester);

        await tester.tap(find.text('Pilih tipe motor'));
        await tester.pumpAndSettle();
        expect(find.text('Pilih Tipe Motor'), findsOneWidget);
        for (final m in [
          'Honda Beat',
          'Honda Vario',
          'Honda Supra X',
          'Yamaha Mio',
        ]) {
          expect(find.widgetWithText(ActionChip, m), findsOneWidget, reason: m);
        }
        expect(find.widgetWithText(ActionChip, 'Universal'), findsNothing);

        await tester.tap(find.widgetWithText(ActionChip, 'Honda Vario'));
        await tester.pumpAndSettle();

        final expected = store.searchProducts(motor: 'Honda Vario');
        expect(
          find.text('${expected.length} sparepart cocok untuk Honda Vario'),
          findsOneWidget,
        );
        expect(find.text('Filter Oli Honda'), findsOneWidget);
        expect(find.text('Busi NGK'), findsOneWidget); // universal
        expect(find.text('Gear Set'), findsNothing); // Supra X
        expect(find.text('Pilih tipe motor'), findsNothing);
      },
    );

    testWidgets('mengetik tipe motor sendiri lalu Terapkan', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Pilih tipe motor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Ketik tipe motor'),
        'Supra',
      );
      await tester.pump();
      // Saran ikut menyempit.
      expect(find.widgetWithText(ActionChip, 'Honda Supra X'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Honda Beat'), findsNothing);
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      expect(find.text('Gear Set'), findsOneWidget);
      expect(find.text('Kampas Rem Depan'), findsNothing);
      expect(find.widgetWithText(InputChip, 'Supra'), findsOneWidget);
    });

    testWidgets(
      'lembar pilihan: filter aktif tidak menyembunyikan saran lain',
      (tester) async {
        await pump(tester, initialMotor: 'Honda Beat Street');

        await tester.tap(find.widgetWithText(InputChip, 'Honda Beat Street'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ActionChip, 'Yamaha Mio'), findsOneWidget);
        expect(
          find.widgetWithText(ActionChip, 'Honda Supra X'),
          findsOneWidget,
        );
      },
    );

    testWidgets('produk sejenis (Honda Matic) ikut tampil untuk Honda Beat', (
      tester,
    ) async {
      await pump(tester);
      await chooseMotor(tester, 'Honda Beat');

      expect(find.text('Oli Gardan 120 ml'), findsOneWidget);
    });

    testWidgets('Termasuk universal dimatikan: produk universal hilang', (
      tester,
    ) async {
      await pump(tester);
      await chooseMotor(tester, 'Honda Beat');
      expect(find.text('Busi NGK'), findsOneWidget);

      await tester.tap(find.text('Termasuk universal'));
      await tester.pump();

      expect(find.text('Busi NGK'), findsNothing);
      expect(find.text('Kampas Rem Depan'), findsOneWidget);

      await tester.tap(find.text('Termasuk universal'));
      await tester.pump();
      expect(find.text('Busi NGK'), findsOneWidget);
    });

    testWidgets('hapus filter lewat chip atau tombol di lembar pilihan', (
      tester,
    ) async {
      await pump(tester);
      await chooseMotor(tester, 'Honda Beat');
      expect(find.text('Gear Set'), findsNothing);

      await tester.tap(find.byTooltip('Hapus filter motor'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih tipe motor'), findsOneWidget);
      expect(find.text('Gear Set'), findsOneWidget);

      await chooseMotor(tester, 'Honda Beat');
      await tester.tap(find.widgetWithText(InputChip, 'Honda Beat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus filter motor'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih tipe motor'), findsOneWidget);
    });

    testWidgets('menutup lembar pilihan tanpa memilih: filter tidak berubah', (
      tester,
    ) async {
      await pump(tester);
      await chooseMotor(tester, 'Honda Beat');

      await tester.tap(find.widgetWithText(InputChip, 'Honda Beat'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // luar lembar
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputChip, 'Honda Beat'), findsOneWidget);
      expect(find.text('Gear Set'), findsNothing);
    });

    testWidgets('tanpa hasil: pesan jelas dengan saran', (tester) async {
      await pump(tester, initialMotor: 'Yamaha NMAX');
      await tester.tap(find.text('Termasuk universal')); // matikan universal
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Tidak ada sparepart untuk "Yamaha NMAX"'),
        findsOneWidget,
      );
      expect(find.textContaining('aktifkan produk universal'), findsOneWidget);
      expect(find.text('0 sparepart cocok untuk Yamaha NMAX'), findsOneWidget);
    });

    testWidgets('initialMotor langsung menyaring', (tester) async {
      await pump(tester, initialMotor: 'Honda Supra X');

      expect(find.widgetWithText(InputChip, 'Honda Supra X'), findsOneWidget);
      expect(find.text('Gear Set'), findsOneWidget);
      expect(find.text('Kampas Rem Depan'), findsNothing);
    });

    testWidgets(
      'Motor saya: tampil bila akun punya motor dan langsung menyaring',
      (tester) async {
        login(withMotor: true);
        await pump(tester);

        expect(find.text('Motor saya: Honda Beat'), findsOneWidget);
        await tester.tap(find.text('Motor saya: Honda Beat'));
        await tester.pumpAndSettle();

        // Nama + tipe: "Honda Beat Street" tetap cocok dengan produk "Honda Beat".
        expect(
          find.widgetWithText(InputChip, 'Honda Beat Street'),
          findsOneWidget,
        );
        expect(find.text('Kampas Rem Depan'), findsOneWidget);
        expect(find.text('Gear Set'), findsNothing);
      },
    );

    testWidgets('Motor saya juga ada di lembar pilihan', (tester) async {
      login(withMotor: true);
      await pump(tester);

      await tester.tap(find.text('Pilih tipe motor'));
      await tester.pumpAndSettle();
      expect(find.text('Motor saya: Honda Beat Street'), findsOneWidget);
      await tester.tap(find.text('Motor saya: Honda Beat Street'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(InputChip, 'Honda Beat Street'),
        findsOneWidget,
      );
    });

    testWidgets('tanpa data motor di akun: tidak ada Motor saya', (
      tester,
    ) async {
      login();
      await pump(tester);

      expect(find.textContaining('Motor saya'), findsNothing);
    });

    testWidgets('digabung dengan kategori dan pencarian', (tester) async {
      await pump(tester, initialMotor: 'Honda Beat');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Oli'));
      await tester.pumpAndSettle();
      expect(find.text('Oli Gardan 120 ml'), findsOneWidget);
      expect(find.text('Kampas Rem Depan'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'gardan');
      await tester.pumpAndSettle();
      expect(find.text('Oli Gardan 120 ml'), findsOneWidget);
      expect(find.text('Oli Mesin Matic 0,8 L'), findsNothing);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'tidak ada overflow di layar kecil (${mode.name}, teks 1.3x)',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          login(withMotor: true);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              home: const CatalogPage(
                initialMotor: 'Honda Beat Street Edition Super Panjang Sekali',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Lembar pilihan motor juga tidak boleh overflow.
          await tester.tap(find.byTooltip('Hapus filter motor'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Pilih tipe motor'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
