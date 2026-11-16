import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/models/review.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

/// Deretan 5 bintang (penuh/setengah/kosong) untuk menampilkan [rating].
class StarRating extends StatelessWidget {
  final double rating;
  final double size;

  const StarRating({super.key, required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star
                : rating >= i - 0.5
                ? Icons.star_half
                : Icons.star_border,
            color: AppColors.star,
            size: size,
          ),
      ],
    );
  }
}

/// Ringkasan rating di halaman detail: "4.5 (3 ulasan)" atau "Belum ada ulasan".
class RatingSummary extends StatelessWidget {
  final Product product;

  const RatingSummary({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final average = store.averageRating(product);
        if (average == null) {
          return Text(
            'Belum ada ulasan',
            style: TextStyle(
              color: context.palette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          );
        }
        final count = store.reviewsFor(product).length;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: AppColors.star, size: 18),
            const SizedBox(width: 6),
            Text(
              average.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            Text(
              '($count)',
              style: TextStyle(color: context.palette.textMuted),
            ),
          ],
        );
      },
    );
  }
}

/// Bagian "Ulasan Pembeli" di halaman detail produk.
class ReviewSection extends StatelessWidget {
  final Product product;

  const ReviewSection({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([store, auth]),
      builder: (context, _) {
        final reviews = store.reviewsFor(product);
        final average = store.averageRating(product);
        final mine = store.myReviewFor(product);

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ulasan Pembeli',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (average != null) ...[
                    StarRating(rating: average),
                    const SizedBox(width: 6),
                    Text(
                      '${average.toStringAsFixed(1)} (${reviews.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (store.canReview(product))
                PrimaryButton(
                  text: mine == null ? 'Tulis Ulasan' : 'Ubah Ulasan Saya',
                  icon: Icons.rate_review_outlined,
                  outline: true,
                  onPressed: () => showReviewDialog(context, product),
                )
              else if (auth.isLoggedIn && !auth.isAdmin)
                Text(
                  'Ulasan hanya untuk pembeli yang pesanannya sudah selesai.',
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: 12,
                  ),
                ),
              if (reviews.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Belum ada ulasan untuk produk ini.',
                    style: TextStyle(color: context.palette.textMuted),
                  ),
                ),
              for (final review in reviews) ReviewTile(review: review),
            ],
          ),
        );
      },
    );
  }
}

class ReviewTile extends StatelessWidget {
  final Review review;
  final VoidCallback? onDelete;

  const ReviewTile({super.key, required this.review, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final mine = review.accountId == store.currentAccountId;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mine ? '${review.authorName} (Anda)' : review.authorName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    StarRating(rating: review.rating.toDouble(), size: 14),
                    const SizedBox(width: 8),
                    Text(
                      formatTanggal(review.createdAt),
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (review.comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    review.comment,
                    style: TextStyle(height: 1.4, color: context.palette.text),
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Hapus ulasan',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
        ],
      ),
    );
  }
}

/// Dialog menulis/mengubah ulasan milik akun aktif.
void showReviewDialog(BuildContext context, Product product) {
  final existing = store.myReviewFor(product);
  final comment = TextEditingController(text: existing?.comment ?? '');
  var rating = existing?.rating ?? 0;
  String? error;

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            title: Text(product.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rating',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          tooltip: '$i bintang',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          onPressed: () => setDialog(() => rating = i),
                          icon: Icon(
                            rating >= i ? Icons.star : Icons.star_border,
                            color: AppColors.star,
                            size: 30,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: comment,
                    maxLines: 4,
                    maxLength: Store.maxCommentLength,
                    decoration: const InputDecoration(
                      labelText: 'Komentar (opsional)',
                    ),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
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
                  final result = store.submitReview(
                    product,
                    rating: rating,
                    comment: comment.text,
                    authorName: auth.currentAccount?.name ?? 'Pembeli',
                  );
                  if (result != null) {
                    setDialog(() => error = result);
                    return;
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text('Kirim'),
              ),
            ],
          );
        },
      );
    },
  );
}
