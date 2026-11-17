import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/models/cart_item.dart';
import 'package:motopart/pages/user/checkout_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/motion.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/product_picture.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  /// Menghapus item dari keranjang dan menawarkan "Batal" untuk mengembalikan.
  void _remove(BuildContext context, CartItem item) {
    final product = item.product;
    final qty = item.qty;
    store.removeCart(product);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${product.name} dihapus dari keranjang'),
        action: SnackBarAction(
          label: 'Batal',
          onPressed: () {
            for (var i = 0; i < qty; i++) {
              if (!store.addToCart(product)) break;
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (store.cart.isEmpty) return const _EmptyCart();

          // Salinan agar aman saat item dihapus lewat geser.
          final items = List<CartItem>.of(store.cart);

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.page,
                  ),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Text(
                        'Geser item ke kiri untuk menghapus',
                        style: TextStyle(
                          color: context.palette.textMuted,
                          fontSize: AppTextSizes.small,
                        ),
                      );
                    }
                    final item = items[index - 1];
                    return _RemovableRow(
                      key: ValueKey('row-${item.product.id}'),
                      builder: (context, remove) => Dismissible(
                        key: ValueKey('cart-${item.product.id}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _remove(context, item),
                        background: const _DismissBackground(),
                        child: _CartItemCard(
                          item: item,
                          // Tombol hapus: baris menciut dulu, baru dihapus.
                          onDelete: () => remove(() => _remove(context, item)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const _Summary(),
            ],
          );
        },
      ),
    );
  }
}

/// Membungkus satu baris keranjang agar bisa "keluar" dengan animasi: menciut,
/// memudar, dan bergeser ke kiri, baru kemudian aksi hapus dijalankan.
class _RemovableRow extends StatefulWidget {
  /// Dipanggil dengan fungsi `remove(aksi)`: memutar animasi keluar lalu
  /// menjalankan [aksi] (mis. menghapus dari keranjang).
  final Widget Function(
    BuildContext context,
    void Function(VoidCallback onGone) remove,
  )
  builder;

  const _RemovableRow({super.key, required this.builder});

  @override
  State<_RemovableRow> createState() => _RemovableRowState();
}

class _RemovableRowState extends State<_RemovableRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  late final Animation<double> curved = CurvedAnimation(
    parent: controller,
    curve: Curves.easeInCubic,
  );
  bool removing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _remove(VoidCallback onGone) async {
    if (removing) return; // ketukan berulang saat animasi berjalan
    removing = true;
    if (UiConfig.animate) {
      await controller.reverse();
      if (!mounted) return;
    }
    onGone();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-0.25, 0),
            end: Offset.zero,
          ).animate(curved),
          child: widget.builder(context, _remove),
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 56,
                  color: palette.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Keranjang masih kosong',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Yuk, temukan sparepart terbaik untuk motormu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                text: 'Mulai Belanja',
                icon: Icons.storefront_rounded,
                onPressed: () => userTabIndex.value = UserTab.home,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Icon(Icons.delete_rounded, color: Colors.white),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onDelete;

  const _CartItemCard({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final product = item.product;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
      child: Row(
        children: [
          ProductPicture.forProduct(product, width: 64, height: 64),
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
                  formatRupiah(product.price),
                  style: TextStyle(
                    color: palette.primaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    _QtyButton(
                      tooltip: 'Kurangi jumlah ${product.name}',
                      icon: Icons.remove_rounded,
                      onTap: () => store.decreaseQty(product),
                    ),
                    SizedBox(
                      width: 32,
                      child: Center(
                        child: AnimatedNumber(
                          value: item.qty,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                      ),
                    ),
                    _QtyButton(
                      tooltip: 'Tambah jumlah ${product.name}',
                      icon: Icons.add_rounded,
                      onTap: () {
                        if (!store.increaseQty(product)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Stok ${product.name} hanya ${product.stock} unit.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus ${product.name}',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: palette.dangerText),
          ),
        ],
      ),
    );
  }
}

/// Tombol -/+ kecil dengan area sentuh 48x48.
class _QtyButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primary.withValues(alpha: 0.14),
        foregroundColor: context.palette.primaryText,
        minimumSize: const Size(AppSizes.minTap, AppSizes.minTap),
        maximumSize: const Size(AppSizes.minTap, AppSizes.minTap),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

/// Ringkasan total dan tombol checkout di bawah daftar.
/// Ringkasan total. Mendengarkan [store] sendiri: widget `const` tidak ikut
/// dibangun ulang oleh pembungkusnya, jadi tanpa ini angkanya basi.
class _Summary extends StatelessWidget {
  const _Summary();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => _SummaryContent(),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  // Sengaja bukan const agar selalu dibangun ulang saat store berubah.
  // ignore: prefer_const_constructors_in_immutables
  _SummaryContent();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.page,
      ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Subtotal (${store.cartCount} barang)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textMuted),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AnimatedCount(
                value: store.cartTotal,
                builder: formatRupiah,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: AppTextSizes.title,
                  color: palette.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 2),
          PrimaryButton(
            text: 'Checkout (${store.cartCount})',
            icon: Icons.lock_outline_rounded,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutPage()),
            ),
          ),
        ],
      ),
    );
  }
}
