import 'package:flutter/material.dart';

/// Ikon yang bisa dipilih untuk kategori (kunci disimpan di perangkat dan
/// database; jangan diubah). Daftar yang sama ada di `backend/src/Domain.php`.
const Map<String, IconData> categoryIcons = {
  'settings': Icons.settings_rounded,
  'album': Icons.album_rounded,
  'oil_barrel': Icons.oil_barrel_rounded,
  'tire_repair': Icons.tire_repair_rounded,
  'electric_bolt': Icons.electric_bolt_rounded,
  'two_wheeler': Icons.two_wheeler_rounded,
  'build': Icons.build_rounded,
  'filter_alt': Icons.filter_alt_rounded,
  'lightbulb': Icons.lightbulb_rounded,
  'speed': Icons.speed_rounded,
  'local_gas_station': Icons.local_gas_station_rounded,
  'handyman': Icons.handyman_rounded,
  'shield': Icons.shield_rounded,
  'tune': Icons.tune_rounded,
};

class ProductCategory {
  final String name;
  final IconData icon;

  const ProductCategory(this.name, this.icon);

  /// Kunci ikon di [categoryIcons] (`build` jika tidak dikenal).
  String get iconKey => categoryIcons.entries
      .firstWhere(
        (e) => e.value == icon,
        orElse: () => const MapEntry('build', Icons.build_rounded),
      )
      .key;

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(
        json['name'] as String,
        categoryIcons[json['icon']] ?? Icons.build_rounded,
      );

  Map<String, dynamic> toJson() => {'name': name, 'icon': iconKey};
}

/// Kategori bawaan (juga data contoh). Daftar yang dipakai aplikasi ada di
/// `store.categories` karena admin bisa menambah, mengubah, dan menghapusnya.
const productCategories = [
  ProductCategory('Mesin', Icons.settings_rounded),
  ProductCategory('Rem', Icons.album_rounded),
  ProductCategory('Oli', Icons.oil_barrel_rounded),
  ProductCategory('Ban', Icons.tire_repair_rounded),
  ProductCategory('Kelistrikan', Icons.electric_bolt_rounded),
  ProductCategory('Body', Icons.two_wheeler_rounded),
  ProductCategory('Transmisi', Icons.build_rounded),
];

List<String> get productCategoryNames => [
  for (final c in productCategories) c.name,
];
