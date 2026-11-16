import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motopart/theme/app_theme.dart';
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
  int? minPrice;
  int? maxPrice;
  ProductSort sort = ProductSort.standard;

  bool get filterActive =>
      minPrice != null || maxPrice != null || sort != ProductSort.standard;

  @override
  void initState() {
    super.initState();
    currentCategory = widget.selectedCategory ?? 'Semua';
  }

  void _openFilterSheet() {
    final minController = TextEditingController(
      text: minPrice?.toString() ?? '',
    );
    final maxController = TextEditingController(
      text: maxPrice?.toString() ?? '',
    );
    var selectedSort = sort;
    String? error;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                0,
                18,
                18 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter & Urutkan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Rentang Harga',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Harga minimum',
                              prefixText: 'Rp',
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('—'),
                        ),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Harga maksimum',
                              prefixText: 'Rp',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Urutkan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in ProductSort.values)
                          ChoiceChip(
                            label: Text(option.label),
                            selected: selectedSort == option,
                            onSelected: (_) =>
                                setSheet(() => selectedSort = option),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                minPrice = null;
                                maxPrice = null;
                                sort = ProductSort.standard;
                              });
                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final min = int.tryParse(minController.text);
                              final max = int.tryParse(maxController.text);
                              if (min != null && max != null && min > max) {
                                setSheet(
                                  () => error =
                                      'Harga minimum tidak boleh lebih besar '
                                      'dari maksimum.',
                                );
                                return;
                              }
                              setState(() {
                                minPrice = min;
                                maxPrice = max;
                                sort = selectedSort;
                              });
                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Terapkan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

    return Scaffold(
      appBar: AppBar(title: const Text('Katalog Produk')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final products = store.searchProducts(
            category: currentCategory,
            keyword: keyword,
            minPrice: minPrice,
            maxPrice: maxPrice,
            sort: sort,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => keyword = value),
                        decoration: const InputDecoration(
                          hintText: 'Cari sparepart...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Badge(
                      isLabelVisible: filterActive,
                      smallSize: 10,
                      child: IconButton.filledTonal(
                        tooltip: 'Filter & urutkan',
                        onPressed: _openFilterSheet,
                        icon: const Icon(Icons.tune),
                      ),
                    ),
                  ],
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
                        selectedColor: AppColors.primary.withValues(
                          alpha: 0.15,
                        ),
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : context.palette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada produk yang cocok.',
                          style: TextStyle(color: context.palette.textMuted),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(18),
                        itemCount: products.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                                  builder: (_) =>
                                      ProductDetailPage(product: product),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
