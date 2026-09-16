import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_item.dart';
import 'srs/srs_engine.dart';

/// Persistence layer around the pure [SrsEngine].
///
/// - `review_events` is append-only: history is never updated or deleted
///   (US-031, data integrity).
/// - `user_items` holds the current scheduling state per item.
class ReviewService {
  ReviewService(this._client, this._engine);

  final SupabaseClient _client;
  final SrsEngine _engine;

  String get _uid => _client.auth.currentUser!.id;

  /// Items due for review, most overdue first (US-030).
  Future<List<UserItem>> dueItems({String? language, int limit = 100}) async {
    var query = _client
        .from('user_items')
        .select()
        .eq('user_id', _uid)
        .lte('next_review', DateTime.now().toUtc().toIso8601String());
    if (language != null) query = query.eq('language', language);
    final rows = await query.order('next_review', ascending: true).limit(limit);
    return rows.map(UserItem.fromJson).toList();
  }

  Future<int> dueCount({String? language}) async {
    var query = _client
        .from('user_items')
        .count(CountOption.exact)
        .eq('user_id', _uid)
        .lte('next_review', DateTime.now().toUtc().toIso8601String());
    if (language != null) query = query.eq('language', language);
    return await query;
  }

  Future<UserItem?> getState(String itemType, String itemId) async {
    final row = await _client
        .from('user_items')
        .select()
        .eq('user_id', _uid)
        .eq('item_type', itemType)
        .eq('item_id', itemId)
        .maybeSingle();
    return row == null ? null : UserItem.fromJson(row);
  }

  /// Ensure an item is tracked so it enters the review queue (first exposure).
  Future<UserItem> ensureTracked(
      String itemType, String itemId, String language) async {
    final existing = await getState(itemType, itemId);
    if (existing != null) return existing;
    final fresh = UserItem(
      userId: _uid,
      itemType: itemType,
      itemId: itemId,
      language: language,
      nextReview: DateTime.now().toUtc(),
    );
    await _client.from('user_items').upsert(fresh.toJson());
    return fresh;
  }

  /// Record one review: append the immutable event, then recompute and store
  /// the item's new scheduling state (US-021/031/032).
  Future<UserItem> recordReview({
    required String itemType,
    required String itemId,
    required String language,
    required ReviewRating rating,
    required String reviewType, // flashcard | exercise | listening | writing
  }) async {
    final now = DateTime.now().toUtc();
    final current = await ensureTracked(itemType, itemId, language);

    await _client.from('review_events').insert({
      'user_id': _uid,
      'item_type': itemType,
      'item_id': itemId,
      'language': language,
      'result': rating != ReviewRating.again,
      'rating': rating.name,
      'review_type': reviewType,
    });

    final result = _engine.review(
      current: SrsState(
        status: current.status,
        ease: current.ease,
        intervalMinutes: current.intervalMinutes,
        repetitions: current.repetitions,
      ),
      rating: rating,
      reviewedAt: now,
    );

    final updated = current.copyWith(
      status: result.state.status,
      ease: result.state.ease,
      intervalMinutes: result.state.intervalMinutes,
      repetitions: result.state.repetitions,
      correctCount:
          current.correctCount + (rating != ReviewRating.again ? 1 : 0),
      incorrectCount:
          current.incorrectCount + (rating == ReviewRating.again ? 1 : 0),
      lastReviewed: now,
      nextReview: result.nextReview,
    );
    await _client.from('user_items').upsert(updated.toJson());
    return updated;
  }

  /// Record a structured exercise attempt (US-022). Also feeds the SRS.
  Future<void> recordExercise({
    required String itemType,
    required String itemId,
    required String language,
    required String exerciseType,
    required bool correct,
    String? answer,
  }) async {
    await _client.from('exercise_attempts').insert({
      'user_id': _uid,
      'item_type': itemType,
      'item_id': itemId,
      'language': language,
      'exercise_type': exerciseType,
      'correct': correct,
      'answer': answer,
    });
    await recordReview(
      itemType: itemType,
      itemId: itemId,
      language: language,
      rating: correct ? ReviewRating.good : ReviewRating.again,
      reviewType: exerciseType,
    );
  }

  /// All tracked states for a language, used for progress and picking new items.
  Future<List<UserItem>> statesFor(String language, {String? itemType}) async {
    var query =
        _client.from('user_items').select().eq('user_id', _uid).eq(
              'language',
              language,
            );
    if (itemType != null) query = query.eq('item_type', itemType);
    final rows = await query;
    return rows.map(UserItem.fromJson).toList();
  }
}
