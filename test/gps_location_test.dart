import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motopart/core/location_service.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/shipping_address.dart';
import 'package:motopart/pages/user/address_form_page.dart';
import 'package:motopart/pages/user/addresses_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

late FakeLocationService fakeLocation;

void resetAll() {
  auth.logout();
  auth.accounts.removeWhere((a) => !a.isAdmin);
  store.setCurrentAccount(Store.guestId);
  fakeLocation = FakeLocationService();
  locationService = fakeLocation;
}

void login() {
  auth.register(
    name: 'Siti Aminah',
    email: 'siti-gps@email.com',
    phone: '081234567890',
    password: 'rahasia1',
  );
  auth.login(
    email: 'siti-gps@email.com',
    password: 'rahasia1',
    role: AccountRole.user,
  );
}

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

/// Lokasi yang baru selesai saat [complete] dipanggil (untuk menguji status
/// "Mencari lokasi...").
class _SlowLocation implements LocationService {
  final completer = Completer<DeviceLocation>();

  @override
  Future<DeviceLocation> currentLocation() => completer.future;

  @override
  Future<PlaceInfo?> reverseGeocode(double latitude, double longitude) async =>
      null;
}

Map<String, dynamic> nominatim(Map<String, String> address) => {
  'address': address,
};

void main() {
  setUp(resetAll);
  tearDown(resetAll);

  group('PlaceInfo.fromNominatim', () {
    test(
      'alamat lengkap: jalan + nomor, kelurahan, kecamatan, kota, kode pos',
      () {
        final place = PlaceInfo.fromNominatim(
          nominatim({
            'road': 'Jalan Braga',
            'house_number': '10',
            'village': 'Braga',
            'city_district': 'Sumur Bandung',
            'city': 'Bandung',
            'postcode': '40111',
            'country': 'Indonesia',
          }),
        )!;

        expect(place.street, 'Jalan Braga No. 10, Braga');
        expect(place.city, 'Sumur Bandung, Bandung');
        expect(place.postalCode, '40111');
      },
    );

    test('tanpa nomor rumah dan tanpa kecamatan', () {
      final place = PlaceInfo.fromNominatim(
        nominatim({'road': 'Jalan Asia Afrika', 'town': 'Lembang'}),
      )!;

      expect(place.street, 'Jalan Asia Afrika');
      expect(place.city, 'Lembang');
      expect(place.postalCode, '');
    });

    test('tanpa jalan: memakai kelurahan/desa', () {
      final place = PlaceInfo.fromNominatim(
        nominatim({'village': 'Cibiru', 'county': 'Kabupaten Bandung'}),
      )!;

      expect(place.street, 'Cibiru');
      expect(place.city, 'Kabupaten Bandung');
    });

    test('kode pos yang bukan 5 angka diabaikan', () {
      final place = PlaceInfo.fromNominatim(
        nominatim({'road': 'Jl. A', 'city': 'Bandung', 'postcode': '4011'}),
      )!;
      expect(place.postalCode, '');
    });

    test('tidak ada alamat berguna: null', () {
      expect(PlaceInfo.fromNominatim({}), isNull);
      expect(
        PlaceInfo.fromNominatim(nominatim({'country': 'Indonesia'})),
        isNull,
      );
      expect(PlaceInfo.fromNominatim({'address': 'bukan map'}), isNull);
      expect(
        PlaceInfo.fromNominatim(nominatim({'road': '  ', 'city': ''})),
        isNull,
      );
    });
  });

  group('DeviceLocationService.reverseGeocode', () {
    test(
      'memanggil Nominatim dengan parameter dan User-Agent yang benar',
      () async {
        late http.Request sent;
        final service = DeviceLocationService(
          client: MockClient((request) async {
            sent = request;
            return http.Response(
              jsonEncode(
                nominatim({
                  'road': 'Jalan Braga',
                  'city': 'Bandung',
                  'postcode': '40111',
                }),
              ),
              200,
            );
          }),
        );

        final place = await service.reverseGeocode(-6.9175, 107.6191);

        expect(sent.url.host, 'nominatim.openstreetmap.org');
        expect(sent.url.path, '/reverse');
        expect(sent.url.queryParameters['lat'], '-6.9175');
        expect(sent.url.queryParameters['lon'], '107.6191');
        expect(sent.url.queryParameters['format'], 'jsonv2');
        expect(sent.url.queryParameters['addressdetails'], '1');
        expect(sent.headers['User-Agent'], 'MotoPartApp/1.0');
        expect(sent.headers['Accept-Language'], 'id');
        expect(place!.street, 'Jalan Braga');
        expect(place.postalCode, '40111');
      },
    );

    test('tanpa internet, status bukan 200, atau respons rusak: null (tidak melempar)', () async {
      Future<PlaceInfo?> run(MockClient client) =>
          DeviceLocationService(client: client).reverseGeocode(1, 2);

      expect(
        await run(MockClient((_) async => throw http.ClientException('putus'))),
        isNull,
      );
      expect(
        await run(MockClient((_) async => http.Response('{}', 429))),
        isNull,
      );
      expect(
        await run(MockClient((_) async => http.Response('bukan json', 200))),
        isNull,
      );
      expect(
        await run(
          MockClient(
            (_) async =>
                http.Response(jsonEncode({'error': 'Unable to geocode'}), 200),
          ),
        ),
        isNull,
      );
    });
  });

  group('ShippingAddress dengan titik GPS', () {
    ShippingAddress address({double? lat = -6.9175, double? lng = 107.6191}) =>
        ShippingAddress(
          id: 'a',
          label: 'Rumah',
          recipient: 'Siti',
          phone: '0812',
          street: 'Jl. A',
          city: 'Bandung',
          latitude: lat,
          longitude: lng,
        );

    test('koordinat tampil 5 desimal dan masuk ke teks pesanan', () {
      final a = address();
      expect(a.hasLocation, isTrue);
      expect(a.coordinatesText, '-6.91750, 107.61910');
      expect(a.orderText, contains('Titik GPS: -6.91750, 107.61910'));
    });

    test('tanpa GPS: tidak ada baris titik GPS', () {
      final a = address(lat: null, lng: null);
      expect(a.hasLocation, isFalse);
      expect(a.coordinatesText, '');
      expect(a.orderText, isNot(contains('GPS')));
    });

    test(
      'JSON bolak-balik, termasuk bilangan bulat dan alamat lama tanpa GPS',
      () {
        final copy = ShippingAddress.fromJson(
          jsonDecode(jsonEncode(address().toJson())) as Map<String, dynamic>,
        );
        expect(copy.latitude, -6.9175);
        expect(copy.longitude, 107.6191);

        final whole = ShippingAddress.fromJson({
          'id': 'a',
          'label': 'R',
          'recipient': 'S',
          'phone': '1',
          'street': 'J',
          'city': 'B',
          'latitude': -6,
          'longitude': 107,
        });
        expect(whole.latitude, -6.0);

        final old = ShippingAddress.fromJson({
          'id': 'a',
          'label': 'R',
          'recipient': 'S',
          'phone': '1',
          'street': 'J',
          'city': 'B',
        });
        expect(old.hasLocation, isFalse);
      },
    );

    test('copyWith: mengganti dan menghapus titik', () {
      final moved = address().copyWith(latitude: 1, longitude: 2);
      expect((moved.latitude, moved.longitude), (1.0, 2.0));
      expect(address().copyWith(clearLocation: true).hasLocation, isFalse);
      expect(address().copyWith(label: 'Kantor').latitude, -6.9175);
    });

    test('validasi koordinat', () {
      String? v({double? lat, double? lng}) => ShippingAddress.validate(
        label: 'R',
        recipient: 'S',
        phone: '081234567',
        street: 'J',
        city: 'B',
        postalCode: '',
        latitude: lat,
        longitude: lng,
      );

      expect(v(), isNull);
      expect(v(lat: -6.9, lng: 107.6), isNull);
      expect(v(lat: -6.9), 'Titik GPS tidak lengkap.');
      expect(v(lng: 107.6), 'Titik GPS tidak lengkap.');
      expect(v(lat: 91, lng: 0), 'Titik GPS tidak valid.');
      expect(v(lat: 0, lng: 181), 'Titik GPS tidak valid.');
      expect(v(lat: -91, lng: 0), 'Titik GPS tidak valid.');
      expect(v(lat: 90, lng: -180), isNull);
    });
  });

  group('AuthStore: alamat dengan titik GPS', () {
    late AuthStore a;
    setUp(() {
      a = AuthStore(store: Store());
      a.register(
        name: 'Siti',
        email: 'siti@email.com',
        phone: '081234567890',
        password: 'rahasia1',
      );
      a.login(
        email: 'siti@email.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );
    });

    String? add({double? lat, double? lng}) => a.addAddress(
      label: 'Rumah',
      recipient: 'Siti',
      phone: '081234567890',
      street: 'Jl. A',
      city: 'Bandung',
      latitude: lat,
      longitude: lng,
    );

    test('menyimpan koordinat', () {
      expect(add(lat: -6.9175, lng: 107.6191), isNull);
      final saved = a.currentAccount!.addresses.single;
      expect(saved.latitude, -6.9175);
      expect(saved.longitude, 107.6191);
    });

    test('koordinat tidak lengkap atau di luar rentang ditolak', () {
      expect(add(lat: 1), 'Titik GPS tidak lengkap.');
      expect(add(lat: 100, lng: 1), 'Titik GPS tidak valid.');
      expect(a.currentAccount!.addresses, isEmpty);
    });

    test('mengubah alamat: titik diganti, atau dihapus bila dikosongkan', () {
      add(lat: -6.9, lng: 107.6);
      final id = a.currentAccount!.addresses.single.id;

      String? update({double? lat, double? lng}) => a.updateAddress(
        id,
        label: 'Rumah',
        recipient: 'Siti',
        phone: '081234567890',
        street: 'Jl. A',
        city: 'Bandung',
        latitude: lat,
        longitude: lng,
      );

      expect(update(lat: -7.0, lng: 108.0), isNull);
      expect(a.currentAccount!.addresses.single.latitude, -7.0);

      expect(update(), isNull); // tanpa titik = hapus titik GPS
      expect(a.currentAccount!.addresses.single.hasLocation, isFalse);
    });

    test('titik GPS bertahan setelah dimuat ulang', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = AuthStore(store: Store());
      await first.attach(prefs);
      first.register(
        name: 'Siti',
        email: 'siti@email.com',
        phone: '081234567890',
        password: 'rahasia1',
      );
      first.login(
        email: 'siti@email.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );
      first.addAddress(
        label: 'Rumah',
        recipient: 'Siti',
        phone: '081234567890',
        street: 'Jl. A',
        city: 'Bandung',
        latitude: -6.9175,
        longitude: 107.6191,
      );

      final reloaded = AuthStore(store: Store());
      await reloaded.attach(prefs);

      final saved = reloaded.currentAccount!.addresses.single;
      expect(saved.latitude, -6.9175);
      expect(saved.longitude, 107.6191);
    });
  });

  group('Form alamat: tombol GPS', () {
    const gpsButton = 'Gunakan Lokasi Saya (GPS)';

    testWidgets('mengisi alamat otomatis dari GPS dan menyimpan titiknya', (
      tester,
    ) async {
      login();
      bigScreen(tester);
      await tester.pumpWidget(app(const AddressFormPage()));

      await tester.tap(find.text(gpsButton));
      await tester.pumpAndSettle();

      expect(fakeLocation.calls, 1);
      expect(find.text('Jl. Braga No. 10, Braga'), findsOneWidget);
      expect(find.text('Sumur Bandung, Bandung'), findsOneWidget);
      expect(find.text('40111'), findsOneWidget);
      expect(find.text('Titik GPS: -6.91750, 107.61910'), findsOneWidget);
      expect(
        find.text(
          'Lokasi ditemukan. Periksa dan lengkapi alamat sebelum menyimpan.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Simpan Alamat'));
      await tester.pumpAndSettle();

      final saved = auth.currentAccount!.addresses.single;
      expect(saved.street, 'Jl. Braga No. 10, Braga');
      expect(saved.postalCode, '40111');
      expect(saved.latitude, -6.9175);
      expect(saved.longitude, 107.6191);
    });

    testWidgets('hasil GPS bisa diedit sebelum disimpan', (tester) async {
      login();
      bigScreen(tester);
      await tester.pumpWidget(app(const AddressFormPage()));
      await tester.tap(find.text(gpsButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Jl. Braga No. 10, Braga'),
        'Jl. Braga No. 12',
      );
      await tester.tap(find.text('Simpan Alamat'));
      await tester.pumpAndSettle();

      expect(auth.currentAccount!.addresses.single.street, 'Jl. Braga No. 12');
      expect(auth.currentAccount!.addresses.single.hasLocation, isTrue);
    });

    testWidgets(
      'alamat tidak ditemukan (tanpa internet): titik tersimpan, isi manual',
      (tester) async {
        login();
        fakeLocation.place = null;
        bigScreen(tester);
        await tester.pumpWidget(app(const AddressFormPage()));

        await tester.tap(find.text(gpsButton));
        await tester.pumpAndSettle();

        expect(find.text('Titik GPS: -6.91750, 107.61910'), findsOneWidget);
        expect(
          find.textContaining('alamat tidak bisa diisi otomatis'),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField).at(3), 'Jl. Manual 1');
        await tester.enterText(find.byType(TextField).at(4), 'Bandung');
        await tester.tap(find.text('Simpan Alamat'));
        await tester.pumpAndSettle();

        final saved = auth.currentAccount!.addresses.single;
        expect(saved.street, 'Jl. Manual 1');
        expect(saved.latitude, -6.9175);
      },
    );

    testWidgets('GPS mati / izin ditolak: pesan tampil, form tidak berubah', (
      tester,
    ) async {
      login();
      fakeLocation.locationError = const LocationException(
        'GPS mati. Aktifkan layanan lokasi lalu coba lagi.',
      );
      bigScreen(tester);
      await tester.pumpWidget(app(const AddressFormPage()));

      await tester.tap(find.text(gpsButton));
      await tester.pumpAndSettle();

      expect(
        find.text('GPS mati. Aktifkan layanan lokasi lalu coba lagi.'),
        findsOneWidget,
      );
      expect(find.textContaining('Titik GPS:'), findsNothing);
      expect(find.text(gpsButton), findsOneWidget); // tombol aktif lagi

      // Izin diberikan, coba lagi.
      fakeLocation.locationError = null;
      await tester.tap(find.text(gpsButton));
      await tester.pumpAndSettle();
      expect(find.text('Titik GPS: -6.91750, 107.61910'), findsOneWidget);
    });

    testWidgets(
      'selama mencari: tombol menampilkan status dan tidak bisa ditekan ganda',
      (tester) async {
        login();
        final slow = _SlowLocation();
        locationService = slow;
        bigScreen(tester);
        await tester.pumpWidget(app(const AddressFormPage()));

        await tester.tap(find.text(gpsButton));
        await tester.pump();

        expect(find.text('Mencari lokasi...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final button = tester.widget<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(button.onPressed, isNull);

        slow.completer.complete(const DeviceLocation(1.5, 2.5));
        await tester.pumpAndSettle();

        expect(find.text('Mencari lokasi...'), findsNothing);
        expect(find.text('Titik GPS: 1.50000, 2.50000'), findsOneWidget);
      },
    );

    testWidgets('hapus titik GPS: alamat tersimpan tanpa koordinat', (
      tester,
    ) async {
      login();
      bigScreen(tester);
      await tester.pumpWidget(app(const AddressFormPage()));
      await tester.tap(find.text(gpsButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Hapus titik GPS'));
      await tester.pump();
      expect(find.textContaining('Titik GPS:'), findsNothing);

      await tester.tap(find.text('Simpan Alamat'));
      await tester.pumpAndSettle();

      expect(auth.currentAccount!.addresses.single.hasLocation, isFalse);
    });

    testWidgets('mengubah alamat yang punya GPS: titik terbawa', (
      tester,
    ) async {
      login();
      auth.addAddress(
        label: 'Rumah',
        recipient: 'Siti',
        phone: '081234567890',
        street: 'Jl. Lama',
        city: 'Bandung',
        latitude: -6.2,
        longitude: 106.8,
      );
      final existing = auth.currentAccount!.addresses.single;
      bigScreen(tester);
      await tester.pumpWidget(app(AddressFormPage(address: existing)));

      expect(find.text('Titik GPS: -6.20000, 106.80000'), findsOneWidget);
      await tester.tap(find.text('Simpan Alamat'));
      await tester.pumpAndSettle();

      expect(auth.currentAccount!.addresses.single.latitude, -6.2);
    });

    testWidgets('daftar alamat menampilkan titik GPS', (tester) async {
      login();
      auth.addAddress(
        label: 'Rumah',
        recipient: 'Siti',
        phone: '081234567890',
        street: 'Jl. A',
        city: 'Bandung',
        latitude: -6.9175,
        longitude: 107.6191,
      );
      bigScreen(tester);
      await tester.pumpWidget(app(const AddressesPage()));

      expect(find.text('GPS: -6.91750, 107.61910'), findsOneWidget);
    });
  });
}
