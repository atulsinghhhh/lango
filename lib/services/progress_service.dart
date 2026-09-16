import 'package:supabase_flutter/supabase_flutter.dart';

/// Per-language, per-skill progress derived from real recorded activity
/// (user_items + exercise_attempts), never from a stored counter (US-110).
class SkillProgress {
  const SkillProgress({required this.skill, required this.percent});

  final String skill;
  final double percent; // 0.0 – 1.0
}

class LanguageProgress {
  const LanguageProgress({required this.language, required this.skills});

  final String language;
  final List<SkillProgress> skills;
}

class ProgressService {
  ProgressService(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  static const _statusWeight = {
    'new': 0.0,
    'learning': 0.25,
    'review': 0.6,
    'mastered': 1.0,
  };

  Future<LanguageProgress> forLanguage(String language) async {
    final results = await Future.wait([
      _coverage(language, 'vocabulary', 'vocabulary'),
      _coverage(language, 'grammar', 'grammar_points'),
      _coverage(language, 'character', 'characters'),
      _accuracy(language, 'listening_choice'),
    ]);
    return LanguageProgress(language: language, skills: [
      SkillProgress(skill: 'Vocabulary', percent: results[0]),
      SkillProgress(skill: 'Grammar', percent: results[1]),
      SkillProgress(skill: 'Writing', percent: results[2]),
      SkillProgress(skill: 'Listening', percent: results[3]),
      // Speaking is P1 — shown honestly as not yet practiced.
      const SkillProgress(skill: 'Speaking', percent: 0),
    ]);
  }

  /// Weighted share of the content catalog the user has progressed through.
  Future<double> _coverage(
      String language, String itemType, String contentTable) async {
    final total = await _client
        .from(contentTable)
        .count(CountOption.exact)
        .eq('language', language);
    if (total == 0) return 0;
    final rows = await _client
        .from('user_items')
        .select('status')
        .eq('user_id', _uid)
        .eq('language', language)
        .eq('item_type', itemType);
    var score = 0.0;
    for (final row in rows) {
      score += _statusWeight[row['status']] ?? 0;
    }
    return (score / total).clamp(0.0, 1.0);
  }

  /// Recent accuracy for a given exercise type (last 50 attempts).
  Future<double> _accuracy(String language, String exerciseType) async {
    final rows = await _client
        .from('exercise_attempts')
        .select('correct')
        .eq('user_id', _uid)
        .eq('language', language)
        .eq('exercise_type', exerciseType)
        .order('created_at', ascending: false)
        .limit(50);
    if (rows.isEmpty) return 0;
    final correct = rows.where((r) => r['correct'] == true).length;
    return correct / rows.length;
  }
}
