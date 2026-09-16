import 'package:supabase_flutter/supabase_flutter.dart';

class SessionSummary {
  const SessionSummary({
    required this.itemsStudied,
    required this.correct,
    required this.incorrect,
    required this.durationSeconds,
    required this.skills,
  });

  final int itemsStudied;
  final int correct;
  final int incorrect;
  final int durationSeconds;
  final List<String> skills;
}

/// Records learning sessions (US-130/131) and daily study aggregates.
class SessionService {
  SessionService(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<String> startSession(String language) async {
    final row = await _client
        .from('learning_sessions')
        .insert({'user_id': _uid, 'language': language})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> completeSession(String sessionId, SessionSummary s) async {
    await _client.from('learning_sessions').update({
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'items_studied': s.itemsStudied,
      'correct_count': s.correct,
      'incorrect_count': s.incorrect,
      'duration_seconds': s.durationSeconds,
      'skills': s.skills,
    }).eq('id', sessionId);
  }

  /// Aggregate review activity since [since] — used to summarize a session
  /// from the immutable event log rather than in-memory counters.
  Future<({int items, int correct, int incorrect})> activitySince(
      DateTime since) async {
    final rows = await _client
        .from('review_events')
        .select('result')
        .eq('user_id', _uid)
        .gte('created_at', since.toUtc().toIso8601String());
    final correct = rows.where((r) => r['result'] == true).length;
    return (
      items: rows.length,
      correct: correct,
      incorrect: rows.length - correct,
    );
  }

  /// Seconds studied today (local day), per language.
  Future<Map<String, int>> secondsStudiedToday() async {
    final startOfDay = DateTime.now();
    final localMidnight =
        DateTime(startOfDay.year, startOfDay.month, startOfDay.day).toUtc();
    final rows = await _client
        .from('learning_sessions')
        .select('language, duration_seconds')
        .eq('user_id', _uid)
        .gte('started_at', localMidnight.toIso8601String());
    final totals = <String, int>{};
    for (final row in rows) {
      final lang = row['language'] as String;
      totals[lang] =
          (totals[lang] ?? 0) + ((row['duration_seconds'] as num?)?.toInt() ?? 0);
    }
    return totals;
  }

  Future<List<Map<String, dynamic>>> recentSessions({int limit = 30}) async {
    return await _client
        .from('learning_sessions')
        .select()
        .eq('user_id', _uid)
        .order('started_at', ascending: false)
        .limit(limit);
  }
}
