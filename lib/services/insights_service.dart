import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/insights.dart';

/// Weak-area analysis (US-100).
///
/// Reads only recorded activity — `exercise_attempts`, `review_events`,
/// `speaking_attempts` — and groups it into categories the learner can act on.
/// A category with too few attempts is dropped rather than reported at low
/// confidence (see [WeakArea.minimumAttempts]).
class InsightsService {
  InsightsService(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  /// How far back to look. Old mistakes the learner has since fixed should not
  /// keep being reported as weaknesses.
  static const _recentAttempts = 200;

  /// A speaking attempt counts as correct when most of the target came back in
  /// the transcript. This grades the *transcript*, not the pronunciation.
  static const _speakingMatchThreshold = 0.7;

  /// Exercise types, as recorded, mapped to the skill a learner recognises.
  static const _skillLabels = <String, String>{
    'listening_choice': 'Listening',
    'dictation': 'Dictation',
    'multiple_choice': 'Recognising words',
    'translation': 'Recalling words',
    'type_answer': 'Typing answers',
    'sentence_completion': 'Words in sentences',
  };

  /// Everything the learner is measurably getting wrong, worst first.
  Future<List<WeakArea>> weakAreas(String language) async {
    final attempts = await _client
        .from('exercise_attempts')
        .select('item_type, item_id, exercise_type, correct')
        .eq('user_id', _uid)
        .eq('language', language)
        .order('created_at', ascending: false)
        .limit(_recentAttempts);

    final areas = <WeakArea>[
      ..._bySkill(attempts),
      ...await _byVocabularyCategory(attempts),
      ...await _byGrammarPoint(attempts),
      ...await _bySpeaking(language),
    ];

    final weak = areas.where((a) => a.isWeak).toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return weak;
  }

  /// Accuracy per exercise type — the "listening mistakes" half of US-100.
  List<WeakArea> _bySkill(List<Map<String, dynamic>> attempts) {
    final tally = <String, _Tally>{};
    for (final row in attempts) {
      final label = _skillLabels[row['exercise_type']];
      if (label == null) continue;
      (tally[label] ??= _Tally()).add(row['correct'] == true);
    }
    return [
      for (final entry in tally.entries)
        WeakArea(
          label: entry.key,
          kind: WeakAreaKind.skill,
          attempts: entry.value.total,
          correct: entry.value.correct,
        ),
    ];
  }

  /// Accuracy per word category. Words carry a part of speech and content
  /// tags, so "particles" or "verbs" falls out of the data rather than being
  /// a hard-coded list.
  Future<List<WeakArea>> _byVocabularyCategory(
      List<Map<String, dynamic>> attempts) async {
    final ids = <String>{
      for (final row in attempts)
        if (row['item_type'] == 'vocabulary') row['item_id'] as String,
    };
    if (ids.isEmpty) return const [];

    final words = await _client
        .from('vocabulary')
        .select('id, part_of_speech, tags')
        .inFilter('id', ids.toList());

    final categories = <String, List<String>>{}; // itemId → category labels
    for (final row in words) {
      final labels = <String>[
        if (row['part_of_speech'] != null)
          _pluralize(row['part_of_speech'] as String),
        ...((row['tags'] as List?)?.cast<String>() ?? const []),
      ];
      categories[row['id'] as String] = labels;
    }

    final tally = <String, _Tally>{};
    final members = <String, Set<String>>{};
    for (final row in attempts) {
      if (row['item_type'] != 'vocabulary') continue;
      final itemId = row['item_id'] as String;
      for (final label in categories[itemId] ?? const <String>[]) {
        (tally[label] ??= _Tally()).add(row['correct'] == true);
        (members[label] ??= <String>{}).add(itemId);
      }
    }

    return [
      for (final entry in tally.entries)
        WeakArea(
          label: entry.key,
          kind: WeakAreaKind.vocabulary,
          attempts: entry.value.total,
          correct: entry.value.correct,
          itemIds: members[entry.key]?.toList() ?? const [],
        ),
    ];
  }

  /// Accuracy per grammar pattern — US-101's worked example
  /// ("Korean 은/는 vs 이/가") lands here.
  Future<List<WeakArea>> _byGrammarPoint(
      List<Map<String, dynamic>> attempts) async {
    final ids = <String>{
      for (final row in attempts)
        if (row['item_type'] == 'grammar') row['item_id'] as String,
    };
    if (ids.isEmpty) return const [];

    final points = await _client
        .from('grammar_points')
        .select('id, name')
        .inFilter('id', ids.toList());
    final names = {
      for (final row in points) row['id'] as String: row['name'] as String,
    };

    final tally = <String, _Tally>{};
    for (final row in attempts) {
      if (row['item_type'] != 'grammar') continue;
      final name = names[row['item_id']];
      if (name == null) continue;
      (tally[name] ??= _Tally()).add(row['correct'] == true);
    }

    return [
      for (final entry in tally.entries)
        WeakArea(
          label: entry.key,
          kind: WeakAreaKind.grammar,
          attempts: entry.value.total,
          correct: entry.value.correct,
          itemIds: [
            for (final e in names.entries)
              if (e.value == entry.key) e.key,
          ],
        ),
    ];
  }

  /// Speaking attempts (US-100 "Speaking attempts").
  ///
  /// Scored on how much of the target sentence the recogniser transcribed —
  /// which is a measure of the attempt, not of pronunciation. The label says
  /// so, because the learner would otherwise read it as a pronunciation score.
  Future<List<WeakArea>> _bySpeaking(String language) async {
    final rows = await _client
        .from('speaking_attempts')
        .select('match_ratio')
        .eq('user_id', _uid)
        .eq('language', language)
        .order('created_at', ascending: false)
        .limit(_recentAttempts);
    if (rows.isEmpty) return const [];

    var correct = 0;
    for (final row in rows) {
      final ratio = (row['match_ratio'] as num?)?.toDouble();
      if (ratio != null && ratio >= _speakingMatchThreshold) correct++;
    }
    return [
      WeakArea(
        label: 'Saying full sentences',
        kind: WeakAreaKind.skill,
        attempts: rows.length,
        correct: correct,
      ),
    ];
  }

  /// Which skills the learner has actually touched since [since].
  ///
  /// Used by the recommendation engine to notice a skill their own goals call
  /// for that they have not practised (US-101). Derived from what was
  /// recorded, so a skill only counts once it has really been used.
  Future<Set<String>> skillsPractisedSince(
      String language, DateTime since) async {
    final sinceUtc = since.toUtc().toIso8601String();

    final results = await Future.wait([
      _client
          .from('exercise_attempts')
          .select('exercise_type, item_type')
          .eq('user_id', _uid)
          .eq('language', language)
          .gte('created_at', sinceUtc)
          .limit(_recentAttempts),
      _client
          .from('speaking_attempts')
          .select('id')
          .eq('user_id', _uid)
          .eq('language', language)
          .gte('created_at', sinceUtc)
          .limit(1),
      _client
          .from('review_events')
          .select('item_type, review_type')
          .eq('user_id', _uid)
          .eq('language', language)
          .gte('created_at', sinceUtc)
          .limit(_recentAttempts),
    ]);

    final skills = <String>{};
    for (final row in results[0]) {
      final type = row['exercise_type'] as String?;
      if (type == 'listening_choice' || type == 'dictation') {
        skills.add('listening');
      }
      if (row['item_type'] == 'grammar') skills.add('grammar');
      if (type != null) skills.add('vocabulary');
    }
    if (results[1].isNotEmpty) skills.add('speaking');
    for (final row in results[2]) {
      if (row['item_type'] == 'grammar') skills.add('grammar');
      if (row['item_type'] == 'character') skills.add('writing');
      if (row['review_type'] == 'listening_choice') skills.add('listening');
    }
    return skills;
  }

  /// "verb" → "Verbs". Good enough for the categories the content actually
  /// uses, and never touches an already-plural tag.
  static String _pluralize(String word) {
    final label = word[0].toUpperCase() + word.substring(1);
    if (label.endsWith('s')) return label;
    return '${label}s';
  }
}

class _Tally {
  int total = 0;
  int correct = 0;

  void add(bool wasCorrect) {
    total++;
    if (wasCorrect) correct++;
  }
}
