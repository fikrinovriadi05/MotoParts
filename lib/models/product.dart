import 'package:flutter/material.dart';

class Product {
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
}
