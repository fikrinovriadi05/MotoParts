import 'package:flutter/material.dart';
import 'package:motopart/core/motor_matching.dart';
import 'package:motopart/core/product_image_storage.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/product_picture.dart';

/// Form tambah produk (jika [product] null) atau edit produk, sebagai halaman
/// penuh: foto (galeri atau URL) dengan pratinjau, nama, kategori, motor yang
/// cocok, harga, stok, dan deskripsi.
class AdminProductFormPage extends StatefulWidget {
  final Product? product;

  const AdminProductFormPage({super.key, this.product});

  @override
  State<AdminProductFormPage> createState() => _AdminProductFormPageState();
}

class _AdminProductFormPageState extends State<AdminProductFormPage> {
  late final Product? product = widget.product;
  late final bool isEdit = product != null;

  late final name = TextEditingController(text: product?.name ?? '');
  late final price = TextEditingController(
    text: product?.price.toString() ?? '',
  );
  late final stock = TextEditingController(
    text: product?.stock.toString() ?? '',
  );
  late final type = TextEditingController(text: product?.type ?? 'Universal');
  late final description = TextEditingController(
    text: product?.description ?? 'Produk baru dari admin.',
  );
  late final url = TextEditingController(
    text: ProductPicture.isNetworkUrl(product?.imagePath)
        ? product!.imagePath
        : '',
  );

  late String category = product?.category ?? 'Mesin';
  late final String? oldImagePath = product?.imagePath;
  late String? imagePath = oldImagePath;

  /// Foto galeri yang dipilih selama form terbuka (disalin ke penyimpanan
  /// app); yang tidak jadi dipakai dihapus saat form ditutup.
  final pickedPaths = <String>[];

  String? error;
  bool saved = false;
  bool busy = false;

  @override
  void dispose() {
    for (final path in pickedPaths) {
      if (!saved || path != imagePath) productImageStorage.delete(path);
    }
    for (final c in [name, price, stock, type, description, url]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Teks galat untuk isian URL, atau null bila kosong/valid.
  String? get urlError {
    final text = url.text.trim();
    if (text.isEmpty || ProductPicture.isNetworkUrl(text)) return null;
    return 'Alamat gambar harus diawali http:// atau https://';
  }

  void _onUrlChanged(String value) {
    final text = value.trim();
    setState(() {
      if (text.isEmpty) {
        // Mengosongkan URL hanya menghapus foto jika fotonya memang URL.
        if (ProductPicture.isNetworkUrl(imagePath)) imagePath = null;
      } else if (ProductPicture.isNetworkUrl(text)) {
        imagePath = text;
      }
    });
  }

  Future<void> _pick() async {
    final String? path;
    try {
      path = await productImageStorage.pickFromGallery();
    } on ProductImageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (path == null) return;
    if (!mounted) {
      productImageStorage.delete(path);
      return;
    }
    pickedPaths.add(path);
    setState(() {
      imagePath = path;
      url.clear();
    });
  }

  Future<void> _save() async {
    if (busy) return;
    final parsedPrice = int.tryParse(price.text.trim());
    final parsedStock = int.tryParse(stock.text.trim());

    String? problem;
    if (name.text.trim().isEmpty) {
      problem = 'Nama produk wajib diisi.';
    } else if (parsedPrice == null || parsedPrice <= 0) {
      problem = 'Harga harus angka lebih dari 0.';
    } else if (parsedStock == null || parsedStock < 0) {
      problem = 'Stok harus angka 0 atau lebih.';
    } else if (urlError != null) {
      problem = urlError;
    }
    if (problem != null) {
      setState(() => error = problem);
      return;
    }

    final typeText = type.text.trim().isEmpty ? 'Universal' : type.text.trim();
    setState(() {
      error = null;
      busy = true;
    });

    if (isEdit) {
      store.updateProduct(
        product!,
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
      final failure = await store.createProduct(
        name: name.text.trim(),
        category: category,
        type: typeText,
        price: parsedPrice!,
        stock: parsedStock!,
        description: description.text.trim(),
        imagePath: imagePath,
      );
      if (!mounted) return;
      if (failure != null) {
        setState(() {
          error = failure;
          busy = false;
        });
        return;
      }
    }

    // Foto lama yang diganti/dihapus tidak dipakai lagi.
    if (oldImagePath != null && oldImagePath != imagePath) {
      productImageStorage.delete(oldImagePath);
    }
    saved = true;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final categories = [
      ...store.categoryNames,
      if (isEdit && !store.categoryNames.contains(product!.category))
        product!.category,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              _PhotoField(
                imagePath: imagePath,
                icon: product?.icon ?? Icons.build_rounded,
                onPick: _pick,
                onRemove: () => setState(() {
                  imagePath = null;
                  url.clear();
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                onChanged: _onUrlChanged,
                decoration: InputDecoration(
                  labelText: 'URL Gambar (opsional)',
                  hintText: 'https://contoh.com/foto.jpg',
                  prefixIcon: const Icon(Icons.link_rounded),
                  errorText: urlError,
                  helperText: 'Atau tempel alamat gambar; pratinjau di atas.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama Produk'),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (value) => setState(() => category = value!),
              ),
              const SizedBox(height: AppSpacing.md),
              _MotorChips(controller: type, onChanged: () => setState(() {})),
              const SizedBox(height: AppSpacing.md),
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
              const SizedBox(height: AppSpacing.md),
              // Harga dan stok berdampingan; di layar sempit bertumpuk.
              LayoutBuilder(
                builder: (context, box) {
                  final priceField = TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga',
                      prefixText: 'Rp ',
                    ),
                  );
                  final stockField = TextField(
                    controller: stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stok'),
                  );
                  if (box.maxWidth < 400) {
                    return Column(
                      children: [
                        priceField,
                        const SizedBox(height: AppSpacing.md),
                        stockField,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: priceField),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: stockField),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: description,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error!,
                  style: TextStyle(
                    color: palette.dangerText,
                    fontSize: AppTextSizes.small,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: busy ? null : _save,
                child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bagian foto di form produk: pratinjau, pilih/ganti, dan hapus foto.
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
          height: 180,
          iconSize: 64,
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

/// Pilihan cepat tipe motor yang cocok. Mengisi dan membaca isian "Tipe
/// Motor" (daftar dipisah koma), jadi bisa dipadukan dengan mengetik.
class _MotorChips extends StatelessWidget {
  static const options = [
    'Universal',
    'Honda Beat',
    'Honda Vario',
    'Honda Scoopy',
    'Honda Supra X',
    'Yamaha Mio',
    'Yamaha NMAX',
    'Yamaha Vixion',
    'Suzuki Satria',
    'Kawasaki Ninja',
  ];

  final TextEditingController controller;
  final VoidCallback onChanged;

  const _MotorChips({required this.controller, required this.onChanged});

  bool _has(List<String> current, String option) =>
      current.any((e) => e.toLowerCase() == option.toLowerCase());

  void _toggle(String option) {
    final current = splitCompatibleBikes(controller.text);
    if (_has(current, option)) {
      current.removeWhere((e) => e.toLowerCase() == option.toLowerCase());
    } else {
      // "Universal" berlaku untuk semua motor: tidak digabung dengan lainnya.
      if (option == 'Universal') {
        current.clear();
      } else {
        current.removeWhere((e) => e.toLowerCase() == 'universal');
      }
      current.add(option);
    }
    controller.text = current.isEmpty ? 'Universal' : current.join(', ');
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final current = splitCompatibleBikes(controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Motor yang cocok',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: context.palette.text,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option),
                selected: _has(current, option),
                onSelected: (_) => _toggle(option),
              ),
          ],
        ),
      ],
    );
  }
}
