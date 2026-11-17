import 'package:flutter/material.dart';
import 'package:motopart/core/categories.dart';
import 'package:motopart/core/product_image_storage.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/product_picture.dart';
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
    final oldImagePath = product?.imagePath;
    String? imagePath = oldImagePath;
    // Foto yang dipilih selama dialog ini terbuka (disalin ke penyimpanan app).
    final pickedPaths = <String>[];
    var saved = false;

    showDialog<void>(
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
                    _PhotoField(
                      imagePath: imagePath,
                      icon: product?.icon ?? Icons.build_rounded,
                      onPick: () async {
                        final String? path;
                        try {
                          path = await productImageStorage.pickFromGallery();
                        } on ProductImageException catch (e) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(
                              dialogContext,
                            ).showSnackBar(SnackBar(content: Text(e.message)));
                          }
                          return;
                        }
                        if (path == null) return;
                        if (!dialogContext.mounted) {
                          productImageStorage.delete(path);
                          return;
                        }
                        pickedPaths.add(path);
                        setDialog(() => imagePath = path);
                      },
                      onRemove: () => setDialog(() => imagePath = null),
                    ),
                    const SizedBox(height: 14),
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
                        helperText:
                            'Pisahkan dengan koma, mis. Honda Beat, Honda '
                            'Vario. Tulis "Universal" untuk semua motor.',
                        helperMaxLines: 3,
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
                        imagePath: imagePath,
                        clearImage: imagePath == null,
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
                          imagePath: imagePath,
                        ),
                      );
                    }

                    // Foto lama yang diganti/dihapus tidak dipakai lagi.
                    if (oldImagePath != null && oldImagePath != imagePath) {
                      productImageStorage.delete(oldImagePath);
                    }
                    saved = true;
                    Navigator.pop(dialogContext);
                  },
                  child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Foto yang dipilih tetapi tidak jadi dipakai dihapus dari penyimpanan.
      for (final path in pickedPaths) {
        if (!saved || path != imagePath) productImageStorage.delete(path);
      }
    });
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
                productImageStorage.delete(product.imagePath);
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
      body: _ProductList(
        onAdd: () => productDialog(context),
        onEdit: (product) => productDialog(context, product: product),
        onReviews: (product) => reviewsDialog(context, product),
        onDelete: (product) => confirmDelete(context, product),
      ),
    );
  }
}

/// Daftar produk admin dengan kolom cari.
class _ProductList extends StatefulWidget {
  final VoidCallback onAdd;
  final ValueChanged<Product> onEdit;
  final ValueChanged<Product> onReviews;
  final ValueChanged<Product> onDelete;

  const _ProductList({
    required this.onAdd,
    required this.onEdit,
    required this.onReviews,
    required this.onDelete,
  });

  @override
  State<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<_ProductList> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final q = query.trim().toLowerCase();
        final products = store.products
            .where(
              (p) =>
                  q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  p.category.toLowerCase().contains(q),
            )
            .toList();

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                hintText: 'Cari nama atau kategori produk',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              text: 'Tambah Produk',
              icon: Icons.add_rounded,
              onPressed: widget.onAdd,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${products.length} produk',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: AppTextSizes.small,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text(
                    'Tidak ada produk yang cocok.',
                    style: TextStyle(color: palette.textMuted),
                  ),
                ),
              ),
            for (final product in products)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ProductTile(
                  product: product,
                  onEdit: () => widget.onEdit(product),
                  onReviews: () => widget.onReviews(product),
                  onDelete: () => widget.onDelete(product),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onReviews;
  final VoidCallback onDelete;

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onReviews,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final low = product.stock < 5;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md + 2,
        AppSpacing.md + 2,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProductPicture.forProduct(product, width: 56, height: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.category} • ${product.type}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: AppTextSizes.small,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${formatRupiah(product.price)} • Stok ${product.stock}',
                      style: TextStyle(
                        color: low ? palette.dangerText : palette.primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: AppTextSizes.small,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Ulasan',
                onPressed: onReviews,
                icon: Icon(
                  Icons.rate_review_outlined,
                  color: palette.textMuted,
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: palette.primaryText),
              ),
              IconButton(
                tooltip: 'Hapus',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: palette.dangerText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bagian foto di dialog produk: pratinjau, pilih/ganti, dan hapus foto.
class _PhotoField extends StatelessWidget {
  final String? imagePath;
  final IconData icon;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoField({
    required this.imagePath,
    required this.icon,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = ProductPicture.hasPhoto(imagePath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductPicture(
          key: const ValueKey('photo-preview'),
          imagePath: imagePath,
          icon: icon,
          height: 140,
          iconSize: 56,
          radius: AppRadius.md,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: Text(hasPhoto ? 'Ganti Foto' : 'Pilih Foto'),
            ),
            if (imagePath != null)
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Hapus Foto'),
              ),
          ],
        ),
      ],
    );
  }
}
