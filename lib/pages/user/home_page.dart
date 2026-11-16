import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motopart/core/categories.dart';
import 'package:motopart/pages/user/catalog_page.dart';
import 'package:motopart/pages/user/category_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/app_logo.dart';
import 'package:motopart/widgets/category_circle.dart';
import 'package:motopart/widgets/product_grid.dart';
import 'package:motopart/widgets/promo_banner.dart';
import 'package:motopart/widgets/section_title.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Jumlah "Produk Terlaris" yang ditampilkan di beranda.
  static const bestSellerCount = 6;

  final search = TextEditingController();
  String keyword = '';
  late bool loading = UiConfig.simulateLoading;
  Timer? loadingTimer;

  @override
  void initState() {
    super.initState();
    if (loading) {
      loadingTimer = Timer(UiConfig.loadingDuration, () {
        if (mounted) setState(() => loading = false);
      });
    }
  }

  @override
  void dispose() {
    loadingTimer?.cancel();
    search.dispose();
    super.dispose();
  }

  void _openCatalog({String? category}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CatalogPage(selectedCategory: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final searching = keyword.trim().isNotEmpty;
            final q = keyword.trim().toLowerCase();
            final products = searching
                ? store.products
                      .where(
                        (p) =>
                            p.name.toLowerCase().contains(q) ||
                            p.category.toLowerCase().contains(q) ||
                            p.type.toLowerCase().contains(q),
                      )
                      .toList()
                : store.productsBySales().take(bestSellerCount).toList();

            return ListView(
              children: [
                _Header(
                  search: search,
                  keyword: keyword,
                  onChanged: (value) => setState(() => keyword = value),
                  onClear: () {
                    search.clear();
                    setState(() => keyword = '');
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: PromoBanner(
                      onTapSlide: (slide) =>
                          _openCatalog(category: slide.category),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.lg,
                    AppSpacing.page,
                    0,
                  ),
                  child: SectionTitle(
                    title: 'Kategori',
                    action: 'Lihat semua',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoryPage()),
                    ),
                  ),
                ),
                SizedBox(
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: productCategories.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final category = productCategories[index];
                      return CategoryCircle(
                        title: category.name,
                        icon: category.icon,
                        onTap: () => _openCatalog(category: category.name),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.md,
                  ),
                  child: SectionTitle(
                    title: searching ? 'Hasil Pencarian' : 'Produk Terlaris',
                    action: 'Katalog',
                    onTap: _openCatalog,
                  ),
                ),
                if (!loading && products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: palette.textMuted,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Tidak ada produk yang cocok.',
                          style: TextStyle(color: palette.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ProductGrid(
                    products: products,
                    loading: loading,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Header gelap: logo, sapaan, dan kolom pencarian besar.
class _Header extends StatelessWidget {
  final TextEditingController search;
  final String keyword;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _Header({
    required this.search,
    required this.keyword,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.charcoal,
            AppColors.charcoalSoft,
            Color(0xFF7A3510),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppLogo(light: true, size: 24),
                ),
              ),
              IconButton(
                tooltip: 'Notifikasi',
                onPressed: () {},
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                ),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedBuilder(
            animation: auth,
            builder: (context, _) => Text(
              auth.currentAccount == null
                  ? 'Halo 👋'
                  : 'Halo, ${auth.currentAccount!.firstName} 👋',
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppTextSizes.heading,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cari sparepart motor terbaik untuk kendaraanmu.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Latar kolom pencarian selalu putih (header selalu gelap), jadi
          // warna teksnya ditetapkan sendiri, bukan dari tema.
          TextField(
            controller: search,
            onChanged: onChanged,
            style: const TextStyle(color: AppColors.charcoal),
            decoration: InputDecoration(
              hintText: 'Cari sparepart atau tipe motor...',
              hintStyle: const TextStyle(color: Color(0xFF6B6B73)),
              prefixIcon: const Icon(Icons.search_rounded),
              prefixIconColor: AppColors.charcoal,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              suffixIcon: keyword.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: onClear,
                      color: AppColors.charcoal,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
