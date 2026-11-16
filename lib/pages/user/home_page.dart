import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/pages/user/catalog_page.dart';
import 'package:motopart/pages/user/category_page.dart';
import 'package:motopart/pages/user/product_detail_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/app_logo.dart';
import 'package:motopart/widgets/category_chip.dart';
import 'package:motopart/widgets/product_card.dart';
import 'package:motopart/widgets/section_title.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final search = TextEditingController();
  String keyword = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = store.products.where((p) {
      return p.name.toLowerCase().contains(keyword.toLowerCase()) ||
          p.category.toLowerCase().contains(keyword.toLowerCase()) ||
          p.type.toLowerCase().contains(keyword.toLowerCase());
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.charcoal,
                    AppColors.charcoalSoft,
                    AppColors.primary,
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppLogo(light: true, size: 24),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.notifications_none,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: auth,
                    builder: (context, _) => Text(
                      auth.currentAccount == null
                          ? 'Halo 👋'
                          : 'Halo, ${auth.currentAccount!.firstName} 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cari sparepart motor terbaik untuk kendaraanmu.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: search,
                    onChanged: (value) => setState(() => keyword = value),
                    decoration: InputDecoration(
                      hintText: 'Cari produk, kategori, atau tipe motor...',
                      prefixIcon: const Icon(Icons.search),
                      fillColor: Colors.white,
                      suffixIcon: keyword.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                search.clear();
                                setState(() => keyword = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.charcoal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROMO SPESIAL',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Diskon\nhingga 30%',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sparepart pilihan dengan harga lebih hemat.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.two_wheeler,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SectionTitle(
                title: 'Kategori',
                action: 'Lihat semua',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoryPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                children: const [
                  CategoryChip(title: 'Mesin', icon: Icons.settings),
                  CategoryChip(title: 'Kelistrikan', icon: Icons.electric_bolt),
                  CategoryChip(title: 'Rem', icon: Icons.disc_full),
                  CategoryChip(title: 'Body', icon: Icons.motorcycle),
                  CategoryChip(title: 'Transmisi', icon: Icons.build),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: SectionTitle(
                title: keyword.isEmpty ? 'Produk Pilihan' : 'Hasil Pencarian',
                action: 'Katalog',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CatalogPage()),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
