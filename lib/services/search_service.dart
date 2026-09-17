import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content.dart';

/// Search across the learning content (US-023, US-140).
///
/// Every query is scoped to one language and paginated — the catalog is never
/// pulled into the client (CLAUDE.md invariant). Matching is trigram-indexed
/// `ilike` (see migration 0002), so it works on native script, romanization
/// and English alike without the learner choosing which they are typing.
class SearchResults {
  const SearchResults({
    this.vocabulary = const [],
    this.grammar = const [],
    this.characters = const [],
  });

  final List<VocabItem> vocabulary;
  final List<GrammarPoint> grammar;
  final List<CharacterItem> characters;

  int get total => vocabulary.length + grammar.length + characters.length;
  bool get isEmpty => total == 0;
}

class SearchService {
  SearchService(this._client);

  final SupabaseClient _client;

  /// Shortest query worth sending. One character matches most of the catalog
  /// in a logographic script and tells the learner nothing.
  static const minQueryLength = 2;

  /// Search vocabulary only (US-023), for the vocabulary browser's filter.
  Future<List<VocabItem>> vocabulary(
    String language,
    String query, {
    int offset = 0,
    int limit = 30,
  }) async {
    final pattern = _pattern(query);
    if (pattern == null) return const [];
    final rows = await _client
        .from('vocabulary')
        .select()
        .eq('language', language)
        .or('word.ilike.$pattern,'
            'romanization.ilike.$pattern,'
            'translation.ilike.$pattern')
        .order('difficulty')
        .order('word')
        .range(offset, offset + limit - 1);
    return rows.map(VocabItem.fromJson).toList();
  }

  /// Search everything for one language (US-140).
  ///
  /// [limit] applies per content type, so one very common English word cannot
  /// crowd the other types out of the results.
  Future<SearchResults> all(
    String language,
    String query, {
    int limit = 20,
  }) async {
    final pattern = _pattern(query);
    if (pattern == null) return const SearchResults();

    final results = await Future.wait([
      vocabulary(language, query, limit: limit),
      _grammar(language, pattern, limit),
      _characters(language, pattern, limit),
    ]);

    return SearchResults(
      vocabulary: results[0] as List<VocabItem>,
      grammar: results[1] as List<GrammarPoint>,
      characters: results[2] as List<CharacterItem>,
    );
  }

  Future<List<GrammarPoint>> _grammar(
      String language, String pattern, int limit) async {
    final rows = await _client
        .from('grammar_points')
        .select('*, grammar_examples(*)')
        .eq('language', language)
        .or('name.ilike.$pattern,meaning.ilike.$pattern')
        .order('difficulty')
        .limit(limit);
    return rows.map(GrammarPoint.fromJson).toList();
  }

  Future<List<CharacterItem>> _characters(
      String language, String pattern, int limit) async {
    final rows = await _client
        .from('characters')
        .select()
        .eq('language', language)
        .or('character.ilike.$pattern,romanization.ilike.$pattern')
        .order('sort_order')
        .limit(limit);
    return rows.map(CharacterItem.fromJson).toList();
  }

  /// Build the `ilike` pattern, or null when the query is not worth a round
  /// trip.
  ///
  /// PostgREST parses `or=(...)` as a comma-separated list with parenthesised
  /// groups, so a comma, parenthesis or quote typed by the learner would
  /// change the meaning of the filter rather than being searched for. Those
  /// characters are dropped, along with the `ilike` wildcards, which would
  /// otherwise let a query match far more than it appears to.
  static String? _pattern(String query) {
    final cleaned = query
        .replaceAll(RegExp(r'''[,()"'\\%_*]'''), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length < minQueryLength) return null;
    // Cap the length so an accidental paste cannot build a huge filter.
    final bounded =
        cleaned.length > 64 ? cleaned.substring(0, 64) : cleaned;
    return '*$bounded*';
  }
}
