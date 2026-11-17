import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/core/motor_matching.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/user/product_image_viewer.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/cart_feedback.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/product_card.dart';
import 'package:motopart/widgets/review_section.dart';
import 'package:motopart/widgets/wishlist_button.dart';

/// Memecah "Honda Beat, Honda Vario" menjadi daftar motor yang cocok.
List<String> compatibleBikes(Product product) =>
    splitCompatibleBikes(product.type);

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int qty = 1;

  Product get product => widget.product;

  void _add() {
    final added = addToCartWithFeedback(context, product, qty: qty);
    if (added > 0) setState(() => qty = 1);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bikes = compatibleBikes(product);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        actions: [WishlistButton(product: product)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        children: [
          Semantics(
            button: true,
            label: 'Gambar ${product.name}, ketuk untuk memperbesar',
            child: MouseRegion(
              cursor: SystemMouseCursors.zoomIn,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => ProductImageViewer(product: product),
                  ),
                ),
                child: Stack(
                  children: [
                    ProductImage(
                      product: product,
                      height: 260,
                      iconSize: 110,
                      radius: AppRadius.xl,
                    ),
                    Positioned(
                      right: AppSpacing.md,
                      bottom: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.zoom_out_map_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            product.name,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatRupiah(product.price),
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedBuilder(
            animation: store,
            builder: (context, _) => Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                RatingSummary(product: product),
                StockLabel(product: product, fontSize: AppTextSizes.body),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Cocok untuk motor',
            style: TextStyle(
              fontSize: AppTextSizes.bodyLarge,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final bike in bikes)
                Chip(
                  avatar: Icon(
                    Icons.two_wheeler_rounded,
                    size: 18,
                    color: palette.primaryText,
                  ),
                  label: Text(bike),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informasi Produk',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _detailRow(context, 'Kategori', product.category),
                AnimatedBuilder(
                  animation: store,
                  builder: (context, _) =>
                      _detailRow(context, 'Stok', '${product.stock} unit'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deskripsi',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  product.description,
                  style: TextStyle(color: palette.textMuted, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ReviewSection(product: product),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        product: product,
        qty: qty,
        onQtyChanged: (value) => setState(() => qty = value),
        onAdd: _add,
      ),
    );
  }

  Widget _detailRow(BuildContext context, String title, String value) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: palette.textMuted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bar bawah yang menempel: pemilih jumlah dan tombol tambah ke keranjang.
class _BottomBar extends StatelessWidget {
  final Product product;
  final int qty;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onAdd;

  const _BottomBar({
    required this.product,
    required this.qty,
    required this.onQtyChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final soldOut = product.stock <= 0;
        final available = product.stock - store.qtyInCart(product);
        final maxedOut = !soldOut && available <= 0;
        final shownQty = qty.clamp(1, available < 1 ? 1 : available);
        final canAdd = !soldOut && !maxedOut;

        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.border)),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  _QuantityPicker(
                    qty: shownQty,
                    canDecrease: canAdd && shownQty > 1,
                    canIncrease: canAdd && shownQty < available,
                    onChanged: onQtyChanged,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      text: soldOut
                          ? 'Stok Habis'
                          : maxedOut
                          ? 'Sudah Maksimum di Keranjang'
                          : 'Tambah ke Keranjang',
                      icon: Icons.add_shopping_cart_rounded,
                      outline: !canAdd,
                      onPressed: canAdd ? onAdd : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pemilih jumlah: (-) 1 (+), tiap tombol berukuran sentuh 48x48.
class _QuantityPicker extends StatelessWidget {
  final int qty;
  final bool canDecrease;
  final bool canIncrease;
  final ValueChanged<int> onChanged;

  const _QuantityPicker({
    required this.qty,
    required this.canDecrease,
    required this.canIncrease,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Kurangi jumlah',
            onPressed: canDecrease ? () => onChanged(qty - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$qty',
              key: const ValueKey('qty-value'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: AppTextSizes.bodyLarge,
                color: palette.text,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tambah jumlah',
            onPressed: canIncrease ? () => onChanged(qty + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
