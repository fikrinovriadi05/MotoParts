import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/pages/user/product_detail_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/product_card.dart';

class CatalogPage extends StatefulWidget {
  final String? selectedCategory;

  const CatalogPage({super.key, this.selectedCategory});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late String currentCategory;
  String keyword = '';

  @override
  void initState() {
    super.initState();
    currentCategory = widget.selectedCategory ?? 'Semua';
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'Semua',
      'Mesin',
      'Kelistrikan',
      'Rem',
      'Body',
      'Transmisi',
    ];

    final products = store.products.where((p) {
      final categoryMatch =
          currentCategory == 'Semua' || p.category == currentCategory;
      final searchMatch = p.name.toLowerCase().contains(keyword.toLowerCase());
      return categoryMatch && searchMatch;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Katalog Produk')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
            child: TextField(
              onChanged: (value) => setState(() => keyword = value),
              decoration: const InputDecoration(
                hintText: 'Cari sparepart...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              children: categories.map((category) {
                final selected = currentCategory == category;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => currentCategory = category);
                    },
                    selectedColor: AppColors.blue.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.blue : AppColors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductCard(
                  product: product,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(product: product),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
