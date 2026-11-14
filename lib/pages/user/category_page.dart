import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/pages/user/catalog_page.dart';
import 'package:motopart/widgets/glass_card.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'name': 'Mesin', 'icon': Icons.settings},
      {'name': 'Kelistrikan', 'icon': Icons.electric_bolt},
      {'name': 'Rem', 'icon': Icons.disc_full},
      {'name': 'Body', 'icon': Icons.motorcycle},
      {'name': 'Transmisi', 'icon': Icons.build},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      body: GridView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.18,
        ),
        itemBuilder: (context, index) {
          final item = categories[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CatalogPage(selectedCategory: item['name'] as String),
                ),
              );
            },
            child: GlassCard(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 42,
                    color: AppColors.blue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item['name'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
