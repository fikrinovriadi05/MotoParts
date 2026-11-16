import 'package:flutter/material.dart';
import 'package:motopart/core/categories.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/review_section.dart';

class AdminProductsPage extends StatelessWidget {
  const AdminProductsPage({super.key});

  static final _categories = productCategoryNames;

  /// Dialog tambah produk (jika [product] null) atau edit produk.
  void productDialog(BuildContext context, {Product? product}) {
    final isEdit = product != null;
    final name = TextEditingController(text: product?.name ?? '');
    final price = TextEditingController(text: product?.price.toString() ?? '');
    final stock = TextEditingController(text: product?.stock.toString() ?? '');
    final type = TextEditingController(text: product?.type ?? 'Universal');
    final description = TextEditingController(
      text: product?.description ?? 'Produk baru dari admin.',
    );
    final categories = [
      ..._categories,
      if (isEdit && !_categories.contains(product.category)) product.category,
    ];
    String category = product?.category ?? 'Mesin';
    String? error;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Nama Produk',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: [
                        for (final c in categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (value) {
                        setDialog(() => category = value!);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: type,
                      decoration: const InputDecoration(
                        labelText: 'Tipe Motor',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stok'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: description,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Deskripsi'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsedPrice = int.tryParse(price.text.trim());
                    final parsedStock = int.tryParse(stock.text.trim());

                    if (name.text.trim().isEmpty) {
                      setDialog(() => error = 'Nama produk wajib diisi.');
                      return;
                    }
                    if (parsedPrice == null || parsedPrice <= 0) {
                      setDialog(
                        () => error = 'Harga harus angka lebih dari 0.',
                      );
                      return;
                    }
                    if (parsedStock == null || parsedStock < 0) {
                      setDialog(() => error = 'Stok harus angka 0 atau lebih.');
                      return;
                    }

                    final typeText = type.text.trim().isEmpty
                        ? 'Universal'
                        : type.text.trim();

                    if (isEdit) {
                      store.updateProduct(
                        product,
                        name: name.text.trim(),
                        category: category,
                        type: typeText,
                        price: parsedPrice,
                        stock: parsedStock,
                        description: description.text.trim(),
                      );
                    } else {
                      store.addProduct(
                        Product(
                          id: DateTime.now().millisecondsSinceEpoch,
                          name: name.text.trim(),
                          category: category,
                          type: typeText,
                          price: parsedPrice,
                          stock: parsedStock,
                          icon: Icons.build_rounded,
                          description: description.text.trim(),
                        ),
                      );
                    }

                    Navigator.pop(dialogContext);
                  },
                  child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Daftar ulasan satu produk; admin bisa menghapus yang tidak pantas.
  void reviewsDialog(BuildContext context, Product product) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Ulasan: ${product.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: AnimatedBuilder(
              animation: store,
              builder: (context, _) {
                final reviews = store.reviewsFor(product);
                if (reviews.isEmpty) {
                  return const Text('Belum ada ulasan.');
                }
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final review in reviews)
                      ReviewTile(
                        review: review,
                        onDelete: () => store.deleteReview(review),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  void confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Produk'),
          content: Text('Hapus "${product.name}" dari daftar produk?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                store.deleteProduct(product);
                Navigator.pop(dialogContext);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Produk')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              PrimaryButton(
                text: 'Tambah Produk',
                icon: Icons.add_rounded,
                onPressed: () => productDialog(context),
              ),
              const SizedBox(height: 14),
              ...store.products.map(
                (product) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(product.icon, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${formatRupiah(product.price)} • Stok ${product.stock}',
                                style: TextStyle(
                                  color: context.palette.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ulasan',
                          onPressed: () => reviewsDialog(context, product),
                          icon: Icon(
                            Icons.rate_review_outlined,
                            color: context.palette.textMuted,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () =>
                              productDialog(context, product: product),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus',
                          onPressed: () => confirmDelete(context, product),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
