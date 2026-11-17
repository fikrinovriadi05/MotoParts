import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motopart/core/categories.dart';
import 'package:motopart/core/motor_matching.dart';
import 'package:flutter/services.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/product_grid.dart';

class CatalogPage extends StatefulWidget {
  final String? selectedCategory;

  /// Tipe motor yang langsung dipakai sebagai filter (opsional).
  final String? initialMotor;

  const CatalogPage({super.key, this.selectedCategory, this.initialMotor});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late String currentCategory;
  String keyword = '';

  /// Filter tipe motor (kosong = tanpa filter) dan apakah produk universal
  /// ikut ditampilkan.
  late String motor = widget.initialMotor?.trim() ?? '';
  bool includeUniversal = true;
  int? minPrice;
  int? maxPrice;
  ProductSort sort = ProductSort.standard;
  late bool loading = UiConfig.simulateLoading;
  Timer? loadingTimer;

  bool get filterActive =>
      minPrice != null || maxPrice != null || sort != ProductSort.standard;

  @override
  void initState() {
    super.initState();
    currentCategory = widget.selectedCategory ?? 'Semua';
    if (loading) {
      loadingTimer = Timer(UiConfig.loadingDuration, () {
        if (mounted) setState(() => loading = false);
      });
    }
  }

  @override
  void dispose() {
    loadingTimer?.cancel();
    super.dispose();
  }

  /// Tarik-untuk-muat-ulang: menampilkan kerangka sesaat lalu daftar terbaru.
  Future<void> _refresh() async {
    setState(() => loading = true);
    await Future<void>.delayed(UiConfig.loadingDuration);
    if (mounted) setState(() => loading = false);
  }

  /// Tipe motor milik akun (nama + tipe), kosong bila belum diisi.
  String get _myMotorQuery => auth.currentAccount?.motorQuery ?? '';

  Future<void> _openMotorSheet() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MotorSheet(
        initial: motor,
        mine: _myMotorQuery,
        suggestions: MotorMatcher.knownMotors(store.products),
      ),
    );

    // null = ditutup tanpa memilih: filter tidak berubah.
    if (chosen != null && mounted) setState(() => motor = chosen);
  }

  /// Label chip yang dipotong (elipsis) agar nama motor panjang tidak
  /// mendorong tombol hapus keluar layar.
  Widget _chipLabel(BuildContext context, String text, double widthFactor) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * widthFactor,
      ),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _motorBar(BuildContext context) {
    final mine = _myMotorQuery;
    final myName = auth.currentAccount?.motorName ?? '';

    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        children: [
          if (motor.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ActionChip(
                avatar: const Icon(Icons.two_wheeler_rounded, size: 18),
                label: const Text('Pilih tipe motor'),
                onPressed: _openMotorSheet,
              ),
            ),
            if (mine.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.person_pin_rounded, size: 18),
                  label: _chipLabel(context, 'Motor saya: $myName', 0.6),
                  onPressed: () => setState(() => motor = mine),
                ),
              ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InputChip(
                avatar: const Icon(Icons.two_wheeler_rounded, size: 18),
                label: _chipLabel(context, motor, 0.5),
                selected: true,
                onPressed: _openMotorSheet,
                onDeleted: () => setState(() => motor = ''),
                deleteButtonTooltipMessage: 'Hapus filter motor',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: const Text('Termasuk universal'),
                selected: includeUniversal,
                onSelected: (v) => setState(() => includeUniversal = v),
              ),
            ),
          ],
        ],
      ),
    );
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
    final categories = ['Semua', ...productCategoryNames];

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
            motor: motor,
            includeUniversal: includeUniversal,
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
                          prefixIcon: Icon(Icons.search_rounded),
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
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              _motorBar(context),
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
                        labelStyle: TextStyle(
                          color: selected
                              ? context.palette.primaryText
                              : context.palette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (motor.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${products.length} sparepart cocok untuk $motor',
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: AppTextSizes.small,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Expanded(
                child: RefreshIndicator(
                  color: context.palette.accent,
                  onRefresh: _refresh,
                  child: !loading && products.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: constraints.maxHeight,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.xl),
                                  child: Text(
                                    motor.isEmpty
                                        ? 'Tidak ada produk yang cocok.'
                                        : 'Tidak ada sparepart untuk '
                                              '"$motor". Coba tipe motor '
                                              'lain${includeUniversal ? '' : ' atau aktifkan produk universal'}.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: context.palette.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : ProductGrid(
                          products: products,
                          loading: loading,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.page),
                          skeletonCount: 6,
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

/// Lembar pilihan tipe motor. Mengembalikan teks pilihan lewat
/// `Navigator.pop` ('' = hapus filter, null = ditutup tanpa memilih).
class _MotorSheet extends StatefulWidget {
  final String initial;
  final String mine;
  final List<String> suggestions;

  const _MotorSheet({
    required this.initial,
    required this.mine,
    required this.suggestions,
  });

  @override
  State<_MotorSheet> createState() => _MotorSheetState();
}

class _MotorSheetState extends State<_MotorSheet> {
  late final controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Saran menyempit hanya setelah pengguna mengubah teks; teks awal (filter
    // yang sedang aktif) tidak menyembunyikan saran lain.
    final typed = controller.text.trim().toLowerCase();
    final editing = typed != widget.initial.trim().toLowerCase();
    final shown = [
      for (final m in widget.suggestions)
        if (!editing || typed.isEmpty || m.toLowerCase().contains(typed)) m,
    ];

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
            Text(
              'Pilih Tipe Motor',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Hanya sparepart yang cocok dengan motor Anda yang ditampilkan.',
              style: TextStyle(color: context.palette.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) => Navigator.pop(context, v.trim()),
              decoration: const InputDecoration(
                labelText: 'Ketik tipe motor',
                hintText: 'mis. Honda Beat',
                prefixIcon: Icon(Icons.two_wheeler_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.mine.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.person_pin_rounded,
                  color: context.palette.primaryText,
                ),
                title: Text('Motor saya: ${widget.mine}'),
                onTap: () => Navigator.pop(context, widget.mine),
              ),
            if (shown.isNotEmpty)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final m in shown)
                    ActionChip(
                      label: Text(m),
                      onPressed: () => Navigator.pop(context, m),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('Hapus filter motor'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
