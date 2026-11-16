import 'package:flutter/material.dart';

class ProductCategory {
  final String name;
  final IconData icon;

  const ProductCategory(this.name, this.icon);
}

/// Kategori produk, dipakai beranda, halaman kategori, katalog, dan form admin.
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
