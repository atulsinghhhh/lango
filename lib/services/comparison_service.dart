import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/comparison.dart';

/// Cross-language comparison (US-120, US-121).
///
/// Concepts are language-neutral rows; the screen picks which two languages to
/// show. Nothing here assumes the pair is Korean and Japanese.
class ComparisonService {
  ComparisonService(this._client);

  final SupabaseClient _client;

  /// Concepts that have an entry in *every* requested language.
  ///
  /// A concept with only one side is not a comparison, so it is filtered out
  /// rather than rendered half-empty.
  Future<List<Concept>> concepts({
    required List<String> languages,
    ConceptKind? kind,
    int limit = 50,
  }) async {
    var query = _client.from('concepts').select('*, concept_entries(*)');
    if (kind != null) query = query.eq('kind', kind.code);
    final rows = await query.order('sort_order').limit(limit);

    return rows
        .map(Concept.fromJson)
        .where((c) => languages.every((l) => c.entryFor(l) != null))
        .toList();
  }
}
