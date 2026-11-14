import 'package:flutter/material.dart';

class Product {
  /// Ikon yang dikenal aplikasi, dipakai untuk menyimpan/memuat produk.
  /// (Tidak menyimpan codePoint mentah agar icon tree-shaking tetap jalan.)
  static const Map<String, IconData> icons = {
    'disc_full': Icons.disc_full,
    'filter_alt': Icons.filter_alt,
    'electric_bolt': Icons.electric_bolt,
    'oil_barrel': Icons.oil_barrel,
    'lightbulb': Icons.lightbulb,
    'settings': Icons.settings,
    'build': Icons.build,
  };

  final int id;
  final String name;
  final String category;
  final String type;
  final int price;
  int stock;
  final IconData icon;
  final String description;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.price,
    required this.stock,
    required this.icon,
    required this.description,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      type: json['type'] as String,
      price: json['price'] as int,
      stock: json['stock'] as int,
      icon: icons[json['icon']] ?? Icons.build,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    final iconName = icons.entries
        .firstWhere(
          (e) => e.value == icon,
          orElse: () => const MapEntry('build', Icons.build),
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
    };
  }
}
