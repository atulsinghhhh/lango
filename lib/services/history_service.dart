import 'package:supabase_flutter/supabase_flutter.dart';

/// One completed learning session (US-131), as it appears in history.
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.language,
    required this.startedAt,
    this.endedAt,
    this.itemsStudied = 0,
    this.correct = 0,
    this.incorrect = 0,
    this.durationSeconds = 0,
    this.skills = const [],
  });

  final String id;
  final String language;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int itemsStudied;
  final int correct;
  final int incorrect;
  final int durationSeconds;
  final List<String> skills;

  bool get completed => endedAt != null;

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        id: json['id'] as String,
        language: json['language'] as String,
        startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'] as String).toLocal()
            : null,
        itemsStudied: (json['items_studied'] as num?)?.toInt() ?? 0,
        correct: (json['correct_count'] as num?)?.toInt() ?? 0,
        incorrect: (json['incorrect_count'] as num?)?.toInt() ?? 0,
        durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
        skills: (json['skills'] as List?)?.cast<String>() ?? const [],
      );
}

/// A single day of recorded activity (US-111).
class HistoryDay {
  const HistoryDay({
    required this.date,
    this.sessions = const [],
    this.reviews = 0,
    this.reviewsCorrect = 0,
    this.exercises = 0,
    this.exercisesCorrect = 0,
    this.speakingAttempts = 0,
  });

  /// Local calendar day, at midnight.
  final DateTime date;
  final List<SessionRecord> sessions;
  final int reviews;
  final int reviewsCorrect;
  final int exercises;
  final int exercisesCorrect;
  final int speakingAttempts;

  int get seconds =>
      sessions.fold(0, (sum, s) => sum + s.durationSeconds);

  int get minutes => (seconds / 60).round();

  int get itemsStudied =>
      sessions.fold(0, (sum, s) => sum + s.itemsStudied);

  /// Null when nothing was graded — a "0%" would be a lie, not a score.
  int? get reviewAccuracyPercent =>
      reviews == 0 ? null : (reviewsCorrect / reviews * 100).round();

  bool get isEmpty =>
      sessions.isEmpty &&
      reviews == 0 &&
      exercises == 0 &&
      speakingAttempts == 0;
}

/// Learning history (US-111).
///
/// Assembled from the immutable event log rather than a stored summary, so it
/// always matches what actually happened.
class HistoryService {
  HistoryService(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  /// Recorded activity by day, newest first.
  ///
  /// [days] bounds the window so the client never pulls a full history; the
  /// screen pages by extending it.
  Future<List<HistoryDay>> recent({String? language, int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final sinceUtc = since.toUtc().toIso8601String();

    final results = await Future.wait([
      _sessions(sinceUtc, language),
      _events('review_events', sinceUtc, language),
      _events('exercise_attempts', sinceUtc, language),
      _speaking(sinceUtc, language),
    ]);

    final sessions = results[0] as List<SessionRecord>;
    final reviews = results[1] as List<_Graded>;
    final exercises = results[2] as List<_Graded>;
    final speaking = results[3] as List<DateTime>;

    final byDay = <DateTime, _DayBuilder>{};
    _DayBuilder day(DateTime at) {
      final key = DateTime(at.year, at.month, at.day);
      return byDay[key] ??= _DayBuilder(key);
    }

    for (final s in sessions) {
      day(s.startedAt).sessions.add(s);
    }
    for (final r in reviews) {
      final b = day(r.at);
      b.reviews++;
      if (r.correct) b.reviewsCorrect++;
    }
    for (final e in exercises) {
      final b = day(e.at);
      b.exercises++;
      if (e.correct) b.exercisesCorrect++;
    }
    for (final at in speaking) {
      day(at).speakingAttempts++;
    }

    final out = byDay.values.map((b) => b.build()).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  Future<List<SessionRecord>> _sessions(String since, String? language) async {
    var query = _client
        .from('learning_sessions')
        .select()
        .eq('user_id', _uid)
        .gte('started_at', since);
    if (language != null) query = query.eq('language', language);
    final rows = await query.order('started_at', ascending: false).limit(200);
    return rows.map(SessionRecord.fromJson).toList();
  }

  /// `review_events.result` and `exercise_attempts.correct` are the same idea
  /// under different column names, so read both through one path.
  Future<List<_Graded>> _events(
      String table, String since, String? language) async {
    final column = table == 'review_events' ? 'result' : 'correct';
    var query = _client
        .from(table)
        .select('created_at, $column')
        .eq('user_id', _uid)
        .gte('created_at', since);
    if (language != null) query = query.eq('language', language);
    final rows = await query.order('created_at', ascending: false).limit(1000);
    return [
      for (final row in rows)
        _Graded(
          DateTime.parse(row['created_at'] as String).toLocal(),
          row[column] == true,
        ),
    ];
  }

  Future<List<DateTime>> _speaking(String since, String? language) async {
    var query = _client
        .from('speaking_attempts')
        .select('created_at')
        .eq('user_id', _uid)
        .gte('created_at', since);
    if (language != null) query = query.eq('language', language);
    final rows = await query.order('created_at', ascending: false).limit(500);
    return [
      for (final row in rows)
        DateTime.parse(row['created_at'] as String).toLocal(),
    ];
  }
}

class _Graded {
  const _Graded(this.at, this.correct);
  final DateTime at;
  final bool correct;
}

class _DayBuilder {
  _DayBuilder(this.date);

  final DateTime date;
  final List<SessionRecord> sessions = [];
  int reviews = 0;
  int reviewsCorrect = 0;
  int exercises = 0;
  int exercisesCorrect = 0;
  int speakingAttempts = 0;

  HistoryDay build() => HistoryDay(
        date: date,
        sessions: sessions,
        reviews: reviews,
        reviewsCorrect: reviewsCorrect,
        exercises: exercises,
        exercisesCorrect: exercisesCorrect,
        speakingAttempts: speakingAttempts,
      );
}
