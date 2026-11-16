import 'package:flutter/material.dart';

class Product {
  /// Ikon yang dikenal aplikasi, dipakai untuk menyimpan/memuat produk.
  /// (Tidak menyimpan codePoint mentah agar icon tree-shaking tetap jalan.)
  static const Map<String, IconData> icons = {
    'disc_full': Icons.disc_full_rounded,
    'filter_alt': Icons.filter_alt_rounded,
    'electric_bolt': Icons.electric_bolt_rounded,
    'oil_barrel': Icons.oil_barrel_rounded,
    'lightbulb': Icons.lightbulb_rounded,
    'settings': Icons.settings_rounded,
    'build': Icons.build_rounded,
  };

  final int id;
  String name;
  String category;
  String type;
  int price;
  int stock;
  final IconData icon;
  String description;

  /// Jalur file foto produk di perangkat (null = tanpa foto, pakai ikon).
  String? imagePath;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.price,
    required this.stock,
    required this.icon,
    required this.description,
    this.imagePath,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      type: json['type'] as String,
      price: json['price'] as int,
      stock: json['stock'] as int,
      icon: icons[json['icon']] ?? Icons.build_rounded,
      description: json['description'] as String,
      imagePath: json['imagePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final iconName = icons.entries
        .firstWhere(
          (e) => e.value == icon,
          orElse: () => const MapEntry('build', Icons.build_rounded),
        )
        .key;
    return {
      'id': id,
      'name': name,
      'category': category,
      'type': type,
      'price': price,
      'stock': stock,
      'icon': iconName,
      'description': description,
      'imagePath': imagePath,
    };
  }
}
