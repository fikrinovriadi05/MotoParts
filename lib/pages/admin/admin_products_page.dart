import 'package:flutter/material.dart';
import 'package:motopart/core/product_image_storage.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/admin/admin_product_form_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/product_picture.dart';
import 'package:motopart/widgets/review_section.dart';

class AdminProductsPage extends StatelessWidget {
  const AdminProductsPage({super.key});

  /// Membuka form tambah produk (jika [product] null) atau edit produk.
  void productDialog(BuildContext context, {Product? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminProductFormPage(product: product)),
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
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
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
                Navigator.pop(dialogContext);
                final removal = store.deleteProduct(product);
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: const Text('Produk dihapus'),
                      persist: false,
                      duration: const Duration(seconds: 6),
                      action: SnackBarAction(
                        label: 'Urungkan',
                        onPressed: () => store.restoreProduct(removal),
                      ),
                    ),
                  ).closed.then((reason) {
                    // Foto baru dibuang jika penghapusan tidak diurungkan.
                    if (reason != SnackBarClosedReason.action) {
                      productImageStorage.delete(product.imagePath);
                    }
                  });
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => productDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Produk'),
      ),
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

  /// Kategori yang dipilih di filter; null = semua.
  String? categoryFilter;

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
                  (categoryFilter == null || p.category == categoryFilter) &&
                  (q.isEmpty ||
                      p.name.toLowerCase().contains(q) ||
                      p.category.toLowerCase().contains(q)),
            )
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page,
            96, // ruang untuk tombol tambah
          ),
          children: [
            TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                hintText: 'Cari nama atau kategori produk',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: categoryFilter == null,
                  onSelected: (_) => setState(() => categoryFilter = null),
                ),
                for (final c in store.categoryNames)
                  ChoiceChip(
                    label: Text(c),
                    selected: categoryFilter == c,
                    onSelected: (_) => setState(() => categoryFilter = c),
                  ),
              ],
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
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 56,
                      color: palette.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      store.products.isEmpty
                          ? 'Belum ada produk.'
                          : 'Tidak ada produk yang cocok.',
                      style: TextStyle(color: palette.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (store.products.isEmpty)
                      FilledButton.icon(
                        onPressed: widget.onAdd,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Tambah Produk Pertama'),
                      )
                    else
                      OutlinedButton(
                        onPressed: () => setState(() {
                          query = '';
                          categoryFilter = null;
                        }),
                        child: const Text('Reset Filter'),
                      ),
                  ],
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
                  onStock: (delta) => store.updateProduct(
                    product,
                    stock: product.stock + delta,
                  ),
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
  final ValueChanged<int> onStock;

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onReviews,
    required this.onDelete,
    required this.onStock,
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Kurangi stok',
                    onPressed: product.stock > 0 ? () => onStock(-1) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${product.stock}',
                      textAlign: TextAlign.center,
                      semanticsLabel: 'Stok ${product.stock}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: low ? palette.dangerText : palette.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tambah stok',
                    onPressed: () => onStock(1),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
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
        ],
      ),
    );
  }
}
