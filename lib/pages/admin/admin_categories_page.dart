import 'package:flutter/material.dart';
import 'package:motopart/core/categories.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/hover.dart';

/// Kelola kategori produk: tambah, ubah nama/ikon, dan hapus.
class AdminCategoriesPage extends StatelessWidget {
  const AdminCategoriesPage({super.key});

  /// Dialog tambah kategori (jika [category] null) atau ubah kategori.
  void categoryDialog(BuildContext context, {ProductCategory? category}) {
    final isEdit = category != null;
    final name = TextEditingController(text: category?.name ?? '');
    var iconKey = category?.iconKey ?? 'build';
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            final palette = context.palette;
            return AlertDialog(
              title: Text(isEdit ? 'Ubah Kategori' : 'Tambah Kategori'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: name,
                      autofocus: true,
                      maxLength: Store.maxCategoryNameLength,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama Kategori',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Ikon',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final entry in categoryIcons.entries)
                          _IconChoice(
                            icon: entry.value,
                            selected: entry.key == iconKey,
                            label: entry.key,
                            onTap: () => setDialog(() => iconKey = entry.key),
                          ),
                      ],
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
                    final result = isEdit
                        ? store.updateCategory(
                            category,
                            name: name.text,
                            iconKey: iconKey,
                          )
                        : store.addCategory(name.text, iconKey);
                    if (result != null) {
                      setDialog(() => error = result);
                      return;
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: Text(isEdit ? 'Simpan' : 'Tambah'),
                ),
              ],
            );
          },
        );
      },
    );
    // Controller tidak di-dispose manual: dialog masih memakainya selama animasi
    // penutupan, dan tanpa pendengar ia aman dibiarkan dibersihkan GC.
  }

  void _delete(BuildContext context, ProductCategory category) {
    final messenger = ScaffoldMessenger.of(context);
    final used = store.productCountIn(category.name);
    if (used > 0) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Kategori "${category.name}" masih dipakai $used produk. '
              'Pindahkan atau hapus produknya dulu.',
            ),
          ),
        );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Hapus kategori "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(dialogContext);
              final error = store.deleteCategory(category);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Kategori dihapus'),
                    persist: false,
                    action: error != null
                        ? null
                        : SnackBarAction(
                            label: 'Urungkan',
                            onPressed: () => store.addCategory(
                              category.name,
                              category.iconKey,
                            ),
                          ),
                  ),
                );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kategori')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => categoryDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Kategori'),
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final categories = store.categories;
          if (categories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 64,
                      color: palette.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Belum ada kategori',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tambahkan kategori agar produk mudah dikelompokkan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: () => categoryDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tambah Kategori'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.page,
              AppSpacing.page,
              96, // ruang untuk tombol tambah
            ),
            children: [
              Text(
                '${categories.length} kategori',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: AppTextSizes.small,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final category in categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _CategoryTile(
                    category: category,
                    productCount: store.productCountIn(category.name),
                    onEdit: () => categoryDialog(context, category: category),
                    onDelete: () => _delete(context, category),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ProductCategory category;
  final int productCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    required this.category,
    required this.productCount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return HoverBuilder(
      cursor: SystemMouseCursors.basic,
      builder: (context, hovered) => AnimatedContainer(
        duration: UiConfig.motion(const Duration(milliseconds: 150)),
        padding: const EdgeInsets.all(AppSpacing.md),
        transform: Matrix4.translationValues(0, hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: hovered
                ? palette.accent.withValues(alpha: 0.5)
                : palette.border,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: hovered ? 18 : 10,
              offset: Offset(0, hovered ? 8 : 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon, color: palette.primaryText),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: AppTextSizes.bodyLarge,
                      color: palette.text,
                    ),
                  ),
                  Text(
                    '$productCount produk',
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: AppTextSizes.small,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ubah ${category.name}',
              onPressed: onEdit,
              icon: Icon(Icons.edit_outlined, color: palette.primaryText),
            ),
            IconButton(
              tooltip: 'Hapus ${category.name}',
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: palette.dangerText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Ikon $label',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('category-icon-$label'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? palette.accent.withValues(alpha: 0.2)
                : palette.surfaceAlt,
            border: Border.all(
              color: selected ? palette.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: selected ? palette.primaryText : palette.textMuted,
          ),
        ),
      ),
    );
  }
}
