import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content.dart';

/// Read access to shared learning content (vocabulary, grammar, characters).
/// Content is paginated — never load the whole database into the client.
class ContentService {
  ContentService(this._client);

  final SupabaseClient _client;

  Future<List<VocabItem>> vocabulary(String language,
      {int offset = 0, int limit = 50}) async {
    final rows = await _client
        .from('vocabulary')
        .select()
        .eq('language', language)
        .order('difficulty')
        .order('word')
        .range(offset, offset + limit - 1);
    return rows.map(VocabItem.fromJson).toList();
  }

  Future<List<VocabItem>> vocabularyByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows =
        await _client.from('vocabulary').select().inFilter('id', ids);
    return rows.map(VocabItem.fromJson).toList();
  }

  Future<int> vocabularyCount(String language) async {
    final res = await _client
        .from('vocabulary')
        .count(CountOption.exact)
        .eq('language', language);
    return res;
  }

  Future<List<GrammarPoint>> grammarPoints(String language) async {
    final rows = await _client
        .from('grammar_points')
        .select('*, grammar_examples(*)')
        .eq('language', language)
        .order('difficulty')
        .order('name');
    return rows.map(GrammarPoint.fromJson).toList();
  }

  Future<int> grammarCount(String language) async {
    final res = await _client
        .from('grammar_points')
        .count(CountOption.exact)
        .eq('language', language);
    return res;
  }

  Future<List<CharacterItem>> characters(
    String language, {
    String? script,
    String? level,
    int offset = 0,
    int limit = 200,
  }) async {
    var query =
        _client.from('characters').select().eq('language', language);
    if (script != null) query = query.eq('script', script);
    if (level != null) query = query.eq('level_label', level);
    final rows = await query
        .order('sort_order')
        .range(offset, offset + limit - 1);
    return rows.map(CharacterItem.fromJson).toList();
  }

  Future<int> charactersCount(String language, {String? script}) async {
    var query = _client
        .from('characters')
        .count(CountOption.exact)
        .eq('language', language);
    if (script != null) query = query.eq('script', script);
    return await query;
  }

  /// Which scripts this language actually has content for.
  ///
  /// Read from the data rather than assumed, so a language that gains a script
  /// later needs no code change (CLAUDE.md: languages are data).
  Future<List<String>> scripts(String language) async {
    final rows = await _client
        .from('characters')
        .select('script')
        .eq('language', language)
        .order('sort_order');
    final seen = <String>[];
    for (final row in rows) {
      final script = row['script'] as String;
      if (!seen.contains(script)) seen.add(script);
    }
    return seen;
  }

  /// Curriculum levels present for a script, e.g. the JLPT bands of the kanji
  /// set. Empty when the script is not levelled.
  Future<List<String>> characterLevels(String language, String script) async {
    final rows = await _client
        .from('characters')
        .select('level_label')
        .eq('language', language)
        .eq('script', script)
        .not('level_label', 'is', null)
        .order('sort_order');
    final seen = <String>[];
    for (final row in rows) {
      final level = row['level_label'] as String;
      if (!seen.contains(level)) seen.add(level);
    }
    return seen;
  }

  /// Example words that use a character (US-061).
  Future<List<VocabItem>> characterVocabulary(String characterId) async {
    final rows = await _client
        .from('character_vocabulary')
        .select('sort_order, vocabulary(*)')
        .eq('character_id', characterId)
        .order('sort_order');
    return [
      for (final row in rows)
        if (row['vocabulary'] != null)
          VocabItem.fromJson((row['vocabulary'] as Map).cast<String, dynamic>()),
    ];
  }
}
