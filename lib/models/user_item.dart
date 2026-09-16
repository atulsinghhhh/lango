/// Per-user spaced-repetition state for one learnable item.
/// Mirrors the `user_items` table. Historical performance lives in the
/// immutable `review_events` table, never here.
class UserItem {
  const UserItem({
    required this.userId,
    required this.itemType,
    required this.itemId,
    required this.language,
    this.status = 'new',
    this.ease = 2.5,
    this.intervalMinutes = 0,
    this.repetitions = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.lastReviewed,
    this.nextReview,
  });

  final String userId;
  final String itemType; // vocabulary | grammar | character
  final String itemId;
  final String language;
  final String status; // new | learning | review | mastered
  final double ease;
  final int intervalMinutes;
  final int repetitions;
  final int correctCount;
  final int incorrectCount;
  final DateTime? lastReviewed;
  final DateTime? nextReview;

  factory UserItem.fromJson(Map<String, dynamic> json) => UserItem(
        userId: json['user_id'] as String,
        itemType: json['item_type'] as String,
        itemId: json['item_id'] as String,
        language: json['language'] as String,
        status: json['status'] as String? ?? 'new',
        ease: (json['ease'] as num?)?.toDouble() ?? 2.5,
        intervalMinutes: (json['interval_minutes'] as num?)?.toInt() ?? 0,
        repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
        correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
        incorrectCount: (json['incorrect_count'] as num?)?.toInt() ?? 0,
        lastReviewed: json['last_reviewed'] != null
            ? DateTime.parse(json['last_reviewed'] as String)
            : null,
        nextReview: json['next_review'] != null
            ? DateTime.parse(json['next_review'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'item_type': itemType,
        'item_id': itemId,
        'language': language,
        'status': status,
        'ease': ease,
        'interval_minutes': intervalMinutes,
        'repetitions': repetitions,
        'correct_count': correctCount,
        'incorrect_count': incorrectCount,
        'last_reviewed': lastReviewed?.toUtc().toIso8601String(),
        'next_review': nextReview?.toUtc().toIso8601String(),
      };

  UserItem copyWith({
    String? status,
    double? ease,
    int? intervalMinutes,
    int? repetitions,
    int? correctCount,
    int? incorrectCount,
    DateTime? lastReviewed,
    DateTime? nextReview,
  }) =>
      UserItem(
        userId: userId,
        itemType: itemType,
        itemId: itemId,
        language: language,
        status: status ?? this.status,
        ease: ease ?? this.ease,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        repetitions: repetitions ?? this.repetitions,
        correctCount: correctCount ?? this.correctCount,
        incorrectCount: incorrectCount ?? this.incorrectCount,
        lastReviewed: lastReviewed ?? this.lastReviewed,
        nextReview: nextReview ?? this.nextReview,
      );
}
