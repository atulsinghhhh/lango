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
      _listening(language),
      _speaking(language),
    ]);
    return LanguageProgress(language: language, skills: [
      SkillProgress(skill: 'Vocabulary', percent: results[0]),
      SkillProgress(skill: 'Grammar', percent: results[1]),
      SkillProgress(skill: 'Writing', percent: results[2]),
      SkillProgress(skill: 'Listening', percent: results[3]),
      SkillProgress(skill: 'Speaking', percent: results[4]),
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

  /// Recent listening accuracy — both the multiple-choice drill and dictation
  /// exercise the same skill, so both count toward it.
  Future<double> _listening(String language) async {
    final rows = await _client
        .from('exercise_attempts')
        .select('correct')
        .eq('user_id', _uid)
        .eq('language', language)
        .inFilter('exercise_type', ['listening_choice', 'dictation'])
        .order('created_at', ascending: false)
        .limit(50);
    if (rows.isEmpty) return 0;
    final correct = rows.where((r) => r['correct'] == true).length;
    return correct / rows.length;
  }

  /// Recent speaking progress (US-080/081/110).
  ///
  /// Measured as the share of recent attempts whose transcript largely matched
  /// the target sentence. That is a measure of attempts made and transcribed —
  /// deliberately **not** a pronunciation score, which nothing here can
  /// produce (CLAUDE.md invariant).
  Future<double> _speaking(String language) async {
    final rows = await _client
        .from('speaking_attempts')
        .select('match_ratio')
        .eq('user_id', _uid)
        .eq('language', language)
        .order('created_at', ascending: false)
        .limit(50);
    if (rows.isEmpty) return 0;
    var matched = 0;
    for (final row in rows) {
      final ratio = (row['match_ratio'] as num?)?.toDouble() ?? 0;
      if (ratio >= 0.7) matched++;
    }
    return matched / rows.length;
  }
}
