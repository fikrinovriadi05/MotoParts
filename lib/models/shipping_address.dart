/// Satu alamat pengiriman tersimpan milik sebuah akun.
class ShippingAddress {
  final String id;

  /// Nama alamat, mis. "Rumah", "Kantor", "Bengkel".
  final String label;
  final String recipient;
  final String phone;

  /// Jalan, nomor rumah, RT/RW, kelurahan.
  final String street;

  /// Kecamatan/kota/kabupaten.
  final String city;
  final String postalCode;

  /// Patokan untuk kurir (opsional), mis. "Pagar hijau dekat masjid".
  final String note;

  /// Titik GPS (opsional); selalu terisi berpasangan.
  final double? latitude;
  final double? longitude;

  const ShippingAddress({
    required this.id,
    required this.label,
    required this.recipient,
    required this.phone,
    required this.street,
    required this.city,
    this.postalCode = '',
    this.note = '',
    this.latitude,
    this.longitude,
  });

  bool get hasLocation => latitude != null && longitude != null;

  /// Koordinat untuk ditampilkan, mis. "-6.91750, 107.61910".
  String get coordinatesText => hasLocation
      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
      : '';

  /// Alamat dalam satu teks, dipakai di ringkasan dan rincian pesanan.
  String get fullText {
    final area = [city, postalCode].where((e) => e.isNotEmpty).join(' ');
    return [street, area].where((e) => e.isNotEmpty).join(', ');
  }

  /// Teks lengkap untuk disimpan di pesanan (nama, telepon, alamat, patokan).
  String get orderText {
    final lines = [
      '$recipient ($phone)',
      fullText,
      if (note.isNotEmpty) 'Patokan: $note',
      if (hasLocation) 'Titik GPS: $coordinatesText',
    ];
    return lines.join('\n');
  }

  /// Pesan kesalahan jika data belum layak disimpan, atau `null`.
  static String? validate({
    required String label,
    required String recipient,
    required String phone,
    required String street,
    required String city,
    required String postalCode,
    double? latitude,
    double? longitude,
  }) {
    if (label.trim().isEmpty ||
        recipient.trim().isEmpty ||
        phone.trim().isEmpty ||
        street.trim().isEmpty ||
        city.trim().isEmpty) {
      return 'Lengkapi nama alamat, penerima, telepon, alamat, dan kota.';
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 8) {
      return 'Nomor telepon tidak valid.';
    }
    final code = postalCode.trim();
    if (code.isNotEmpty && !RegExp(r'^\d{5}$').hasMatch(code)) {
      return 'Kode pos harus 5 angka.';
    }
    if ((latitude == null) != (longitude == null)) {
      return 'Titik GPS tidak lengkap.';
    }
    if (latitude != null &&
        (latitude < -90 ||
            latitude > 90 ||
            longitude! < -180 ||
            longitude > 180)) {
      return 'Titik GPS tidak valid.';
    }
    return null;
  }

  ShippingAddress copyWith({
    String? label,
    String? recipient,
    String? phone,
    String? street,
    String? city,
    String? postalCode,
    String? note,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
  }) {
    return ShippingAddress(
      id: id,
      label: label?.trim() ?? this.label,
      recipient: recipient?.trim() ?? this.recipient,
      phone: phone?.trim() ?? this.phone,
      street: street?.trim() ?? this.street,
      city: city?.trim() ?? this.city,
      postalCode: postalCode?.trim() ?? this.postalCode,
      note: note?.trim() ?? this.note,
      latitude: clearLocation ? null : latitude ?? this.latitude,
      longitude: clearLocation ? null : longitude ?? this.longitude,
    );
  }

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      id: json['id'] as String,
      label: json['label'] as String,
      recipient: json['recipient'] as String,
      phone: json['phone'] as String,
      street: json['street'] as String,
      city: json['city'] as String,
      postalCode: json['postalCode'] as String? ?? '',
      note: json['note'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'recipient': recipient,
    'phone': phone,
    'street': street,
    'city': city,
    'postalCode': postalCode,
    'note': note,
    'latitude': latitude,
    'longitude': longitude,
  };
}
