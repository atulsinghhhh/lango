import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import 'starter_track.dart';

/// Measures the learner so [StarterTrack] can order their path.
///
/// Everything here is derived from recorded activity — `user_items`,
/// `exercise_attempts`, `speaking_attempts`, `tutor_messages` — never from a
/// "completed the tutorial" flag. A learner who reinstalls, or who learned
/// Hangul before the track existed, is met where they actually are.
class StarterTrackService {
  StarterTrackService(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  /// Statuses that count as having started an item. `new` means the row exists
  /// because the item was queued, not because it was studied, so it does not
  /// count — otherwise queueing a deck would tick off the whole track.
  static const _startedStatuses = ['learning', 'review', 'mastered'];

  Future<StarterSnapshot> snapshot(UserLanguage userLanguage) async {
    final language = userLanguage.language.code;

    final results = await Future.wait([
      _scriptProgress(language),
      _startedCount(language, 'vocabulary'),
      _startedCount(language, 'grammar'),
      _hasExercise(language, const ['listening_choice']),
      _hasExercise(language, const ['dictation']),
      _hasSpoken(language),
      _hasMessagedTutor(),
    ]);

    return StarterSnapshot(
      language: userLanguage.language,
      level: userLanguage.level,
      scripts: results[0] as List<ScriptProgress>,
      vocabularyTracked: results[1] as int,
      grammarTracked: results[2] as int,
      hasListened: results[3] as bool,
      hasTakenDictation: results[4] as bool,
      hasSpoken: results[5] as bool,
      hasMessagedTutor: results[6] as bool,
    );
  }

  /// Per-script totals and how many of each the learner has started.
  ///
  /// `user_items.item_id` is polymorphic and carries no foreign key, so the
  /// join cannot be pushed into PostgREST. Instead: one query for the tracked
  /// character ids, one for the catalog's characters. Both are bounded by the
  /// size of the writing systems — tens of rows, not thousands — and the
  /// grouping happens here.
  Future<List<ScriptProgress>> _scriptProgress(String language) async {
    final results = await Future.wait([
      _client
          .from('characters')
          .select('id, script, level_label, sort_order')
          .eq('language', language)
          .order('sort_order'),
      _client
          .from('user_items')
          .select('item_id')
          .eq('user_id', _uid)
          .eq('language', language)
          .eq('item_type', 'character')
          .inFilter('status', _startedStatuses),
    ]);

    final started = {
      for (final row in results[1]) row['item_id'] as String,
    };

    // Insertion-ordered, so scripts come back in catalog order and Hiragana
    // precedes Katakana because its rows sort first — the order is content's
    // to decide, not this file's.
    final totals = <String, int>{};
    final learned = <String, int>{};
    final levelled = <String, bool>{};

    for (final row in results[0]) {
      final script = row['script'] as String;
      totals[script] = (totals[script] ?? 0) + 1;
      learned[script] = (learned[script] ?? 0) +
          (started.contains(row['id'] as String) ? 1 : 0);
      // A script counts as levelled as soon as any of its rows carries a band.
      levelled[script] =
          (levelled[script] ?? false) || row['level_label'] != null;
    }

    return [
      for (final entry in totals.entries)
        ScriptProgress(
          script: entry.key,
          learned: learned[entry.key] ?? 0,
          total: entry.value,
          isLevelled: levelled[entry.key] ?? false,
        ),
    ];
  }

  Future<int> _startedCount(String language, String itemType) async {
    return await _client
        .from('user_items')
        .count(CountOption.exact)
        .eq('user_id', _uid)
        .eq('language', language)
        .eq('item_type', itemType)
        .inFilter('status', _startedStatuses);
  }

  /// Whether a mode has ever been used. Only existence matters, so every one
  /// of these asks for a single row rather than a count over the history.
  Future<bool> _hasExercise(String language, List<String> types) async {
    final rows = await _client
        .from('exercise_attempts')
        .select('id')
        .eq('user_id', _uid)
        .eq('language', language)
        .inFilter('exercise_type', types)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<bool> _hasSpoken(String language) async {
    final rows = await _client
        .from('speaking_attempts')
        .select('id')
        .eq('user_id', _uid)
        .eq('language', language)
        .limit(1);
    return rows.isNotEmpty;
  }

  /// Tutor messages are not language-scoped — the conversation is — and a
  /// learner who has held one conversation has met the mode. Only the
  /// learner's own turns count: a greeting from the tutor is not participation.
  Future<bool> _hasMessagedTutor() async {
    final rows = await _client
        .from('tutor_messages')
        .select('id')
        .eq('user_id', _uid)
        .eq('role', 'user')
        .limit(1);
    return rows.isNotEmpty;
  }
}
