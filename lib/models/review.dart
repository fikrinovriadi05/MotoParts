class Review {
  final int productId;
  final String accountId;
  final String authorName;
  final int rating; // 1-5
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.productId,
    required this.accountId,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      productId: json['productId'] as int,
      accountId: json['accountId'] as String,
      authorName: json['authorName'] as String,
      rating: json['rating'] as int,
      comment: (json['comment'] as String?) ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'accountId': accountId,
    'authorName': authorName,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
  };
}
