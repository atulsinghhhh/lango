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

  Future<List<CharacterItem>> characters(String language,
      {String? script}) async {
    var query =
        _client.from('characters').select().eq('language', language);
    if (script != null) query = query.eq('script', script);
    final rows = await query.order('sort_order');
    return rows.map(CharacterItem.fromJson).toList();
  }
}
