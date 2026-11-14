import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

class AdminProductsPage extends StatelessWidget {
  const AdminProductsPage({super.key});

  void addProductDialog(BuildContext context) {
    final name = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController();
    String category = 'Mesin';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              title: const Text('Tambah Produk'),
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
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Mesin',
                          child: Text('Mesin'),
                        ),
                        DropdownMenuItem(
                          value: 'Kelistrikan',
                          child: Text('Kelistrikan'),
                        ),
                        DropdownMenuItem(
                          value: 'Rem',
                          child: Text('Rem'),
                        ),
                        DropdownMenuItem(
                          value: 'Body',
                          child: Text('Body'),
                        ),
                        DropdownMenuItem(
                          value: 'Transmisi',
                          child: Text('Transmisi'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialog(() => category = value!);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stok',
                      ),
                    ),
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
                    final parsedPrice = int.tryParse(price.text);
                    final parsedStock = int.tryParse(stock.text);

                    if (name.text.trim().isEmpty ||
                        parsedPrice == null ||
                        parsedStock == null) {
                      return;
                    }

                    store.addProduct(
                      Product(
                        id: DateTime.now().millisecondsSinceEpoch,
                        name: name.text.trim(),
                        category: category,
                        type: 'Universal',
                        price: parsedPrice,
                        stock: parsedStock,
                        icon: Icons.build,
                        description: 'Produk baru dari admin.',
                      ),
                    );

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Produk'),
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              PrimaryButton(
                text: 'Tambah Produk',
                icon: Icons.add,
                onPressed: () => addProductDialog(context),
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
                            color: AppColors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            product.icon,
                            color: AppColors.blue,
                          ),
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
                                style: const TextStyle(
                                  color: AppColors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            store.deleteProduct(product);
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.red,
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
