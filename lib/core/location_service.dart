import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Koordinat GPS perangkat.
class DeviceLocation {
  final double latitude;
  final double longitude;

  const DeviceLocation(this.latitude, this.longitude);
}

/// Alamat hasil pencarian dari koordinat, siap mengisi form alamat.
class PlaceInfo {
  final String street;
  final String city;
  final String postalCode;

  const PlaceInfo({
    required this.street,
    required this.city,
    required this.postalCode,
  });

  /// Membaca respons `reverse` OpenStreetMap Nominatim (format jsonv2 dengan
  /// addressdetails). Mengembalikan null jika tidak ada alamat yang berguna.
  static PlaceInfo? fromNominatim(Map<String, dynamic> json) {
    final address = json['address'];
    if (address is! Map) return null;

    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = address[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    final road = pick(['road', 'pedestrian', 'residential', 'footway', 'path']);
    final number = pick(['house_number']);
    final village = pick(['village', 'suburb', 'neighbourhood', 'quarter']);
    final district = pick(['city_district', 'subdistrict', 'district']);
    final town = pick(['city', 'town', 'municipality', 'regency', 'county']);

    final street = [
      if (road != null) number == null ? road : '$road No. $number',
      ?village,
    ].join(', ');
    final city = [?district, ?town].join(', ');
    if (street.isEmpty && city.isEmpty) return null;

    return PlaceInfo(
      street: street,
      city: city,
      postalCode: RegExp(r'^\d{5}$').hasMatch(pick(['postcode']) ?? '')
          ? pick(['postcode'])!
          : '',
    );
  }
}

/// Kesalahan yang bisa ditampilkan langsung ke pengguna.
class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}

/// Pembaca lokasi GPS dan pencari alamat dari koordinat.
abstract class LocationService {
  /// Lokasi saat ini. Melempar [LocationException] jika GPS mati, izin
  /// ditolak, atau lokasi tidak ditemukan.
  Future<DeviceLocation> currentLocation();

  /// Alamat dari koordinat; null jika tidak bisa ditemukan (mis. tanpa
  /// internet). Tidak melempar.
  Future<PlaceInfo?> reverseGeocode(double latitude, double longitude);
}

class DeviceLocationService implements LocationService {
  final http.Client _client;

  DeviceLocationService({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<DeviceLocation> currentLocation() async {
    try {
      return await _locate();
    } on LocationException {
      rethrow;
    } on TimeoutException {
      throw const LocationException(
        'Lokasi belum ditemukan. Coba lagi di tempat terbuka.',
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        'GPS mati. Aktifkan layanan lokasi lalu coba lagi.',
      );
    } on PermissionDeniedException {
      throw const LocationException('Izin lokasi ditolak.');
    } on Object {
      // Platform tanpa GPS/izin (mis. browser yang memblokir lokasi).
      throw const LocationException(
        'Lokasi tidak dapat diakses di perangkat ini. '
        'Isi alamat secara manual.',
      );
    }
  }

  Future<DeviceLocation> _locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'GPS mati. Aktifkan layanan lokasi lalu coba lagi.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Izin lokasi ditolak permanen. Aktifkan lewat Pengaturan aplikasi '
        'atau pengaturan situs di browser.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Izin lokasi ditolak.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return DeviceLocation(position.latitude, position.longitude);
  }

  @override
  Future<PlaceInfo?> reverseGeocode(double latitude, double longitude) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$latitude',
        'lon': '$longitude',
        'zoom': '18',
        'addressdetails': '1',
      });
      final response = await _client
          .get(
            uri,
            headers: {
              // Kebijakan Nominatim: wajib mengenali aplikasi pemanggil.
              'User-Agent': 'MotoPartApp/1.0',
              'Accept-Language': 'id',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return PlaceInfo.fromNominatim(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }
}

/// Dipakai halaman; diganti di tes.
LocationService locationService = DeviceLocationService();
