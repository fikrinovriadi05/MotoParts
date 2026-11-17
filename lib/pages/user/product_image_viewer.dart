import 'package:flutter/material.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/product_card.dart';
import 'package:motopart/widgets/product_picture.dart';

/// Gambar produk layar penuh: cubit untuk memperbesar (sampai [maxScale]x),
/// geser untuk melihat bagian lain, ketuk dua kali untuk memperbesar/mengembalikan.
class ProductImageViewer extends StatefulWidget {
  static const maxScale = 5.0;
  static const doubleTapScale = 2.5;

  final Product product;

  const ProductImageViewer({super.key, required this.product});

  /// Skala (kelipatan) transformasi [m].
  static double scaleOf(Matrix4 m) => m.getMaxScaleOnAxis();

  @override
  State<ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<ProductImageViewer>
    with SingleTickerProviderStateMixin {
  final transform = TransformationController();
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Matrix4? _from;
  Matrix4? _to;
  Offset doubleTapAt = Offset.zero;

  bool get zoomed => ProductImageViewer.scaleOf(transform.value) > 1.01;

  @override
  void initState() {
    super.initState();
    animation.addListener(_tick);
  }

  @override
  void dispose() {
    animation.dispose();
    transform.dispose();
    super.dispose();
  }

  void _tick() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    transform.value = _lerp(
      from,
      to,
      Curves.easeOutCubic.transform(animation.value),
    );
  }

  /// Interpolasi per elemen. Cukup untuk matriks geser + skala seragam seperti
  /// di sini (tanpa putaran).
  static Matrix4 _lerp(Matrix4 a, Matrix4 b, double t) {
    final out = Matrix4.zero();
    for (var i = 0; i < 16; i++) {
      out.storage[i] = a.storage[i] + (b.storage[i] - a.storage[i]) * t;
    }
    return out;
  }

  /// Ketuk dua kali: memperbesar di titik ketukan, atau kembali ke ukuran awal.
  void _toggleZoom() {
    const s = ProductImageViewer.doubleTapScale;
    final target = zoomed
        ? Matrix4.identity()
        : Matrix4.translationValues(
                -doubleTapAt.dx * (s - 1),
                -doubleTapAt.dy * (s - 1),
                0,
              ) *
              Matrix4.diagonal3Values(s, s, 1);

    if (!UiConfig.animate) {
      transform.value = target;
      return;
    }
    _from = Matrix4.copy(transform.value);
    _to = target;
    animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTapDown: (d) => doubleTapAt = d.localPosition,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: transform,
                minScale: 1,
                maxScale: ProductImageViewer.maxScale,
                child: Center(
                  child: Hero(
                    tag: productHeroTag(widget.product),
                    child: ProductPicture.forProduct(
                      widget.product,
                      width: size.width,
                      height: size.height * 0.7,
                      iconSize: size.width * 0.45,
                      radius: 0,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: IconButton.filledTonal(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  widget.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: AppTextSizes.bodyLarge,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                  0,
                ),
                child: Text(
                  'Cubit atau ketuk dua kali',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: AppTextSizes.small,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
