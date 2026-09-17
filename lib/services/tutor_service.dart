import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/language.dart';
import '../models/tutor.dart';

/// AI tutor (US-090, US-091, US-092).
///
/// The model itself is reached through the `tutor` Edge Function, which holds
/// the API key server-side (see `supabase/functions/tutor/index.ts`). This
/// service owns everything else: what the tutor is told about the learner, and
/// the stored history of what was actually said.
///
/// When the function is not deployed, every call throws [TutorUnavailable]
/// with [TutorUnavailableReason.notConfigured] so the UI can say that plainly
/// instead of pretending to hold a conversation.
class TutorService {
  TutorService(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  /// How much studied material to hand the tutor. Enough to keep it inside the
  /// learner's range, small enough that the request stays cheap.
  static const _vocabularyContextSize = 80;
  static const _mistakeContextSize = 12;

  /// Whether a tutor backend is actually deployed for this project.
  ///
  /// A cheap `GET` against the function — no model call, so asking costs
  /// nothing. The UI asks before offering a conversation, so a project with no
  /// tutor deployed says so up front rather than failing on the learner's
  /// first message.
  Future<bool> isAvailable() async {
    try {
      final response = await _client.functions
          .invoke('tutor', method: HttpMethod.get);
      return response.status == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Conversations ─────────────────────────────────────────────────────────

  Future<List<TutorConversation>> conversations({
    String? language,
    int limit = 30,
  }) async {
    var query =
        _client.from('tutor_conversations').select().eq('user_id', _uid);
    if (language != null) query = query.eq('language', language);
    final rows = await query.order('started_at', ascending: false).limit(limit);
    return rows.map(TutorConversation.fromJson).toList();
  }

  Future<TutorConversation> startConversation({
    required TargetLanguage language,
    required ProficiencyLevel level,
    String? scenario,
    String? title,
  }) async {
    final row = await _client
        .from('tutor_conversations')
        .insert({
          'user_id': _uid,
          'language': language.code,
          'level': level.code,
          'scenario': scenario,
          'title': title ?? scenario,
        })
        .select()
        .single();
    return TutorConversation.fromJson(row);
  }

  Future<void> endConversation(String conversationId) async {
    await _client
        .from('tutor_conversations')
        .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', conversationId);
  }

  Future<List<TutorMessage>> messages(String conversationId) async {
    final rows = await _client
        .from('tutor_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return rows.map(TutorMessage.fromJson).toList();
  }

  // ── Turns ─────────────────────────────────────────────────────────────────

  /// Send one learner turn and store both sides of the exchange.
  ///
  /// The learner's message is stored first, so a backend failure loses the
  /// reply but never the learner's own words.
  Future<TutorMessage> send({
    required TutorConversation conversation,
    required String text,
    required TutorContext context,
  }) async {
    await _store(conversation.id, TutorRole.user, text);

    final history = await messages(conversation.id);
    final reply = await _turn(context, history);

    return _store(
      conversation.id,
      TutorRole.tutor,
      reply.content,
      translation: reply.translation,
      correction: reply.correction,
    );
  }

  /// Ask the tutor to open the conversation, so a learner facing a blank
  /// screen in a language they barely read is not the one who has to start.
  Future<TutorMessage> openingTurn({
    required TutorConversation conversation,
    required TutorContext context,
  }) async {
    final reply = await _turn(context, const [], opening: true);
    return _store(
      conversation.id,
      TutorRole.tutor,
      reply.content,
      translation: reply.translation,
    );
  }

  Future<_TutorReply> _turn(
    TutorContext context,
    List<TutorMessage> history, {
    bool opening = false,
  }) async {
    final payload = [
      for (final m in history)
        {
          'role': m.role == TutorRole.user ? 'user' : 'tutor',
          'content': m.content,
        },
      if (opening)
        {
          'role': 'user',
          // The API requires a user turn to start; this is an instruction to
          // the tutor, not something the learner typed, so it is never stored.
          'content': 'Start the conversation.',
        },
    ];

    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'tutor',
        body: {'context': context.toJson(), 'messages': payload},
      );
    } on FunctionException catch (e) {
      // 404 means no function is deployed; 503 means it is deployed without an
      // API key. Both are "this project has no tutor backend", which is a
      // different message from "something went wrong".
      throw TutorUnavailable(
        e.status == 404 || e.status == 503
            ? TutorUnavailableReason.notConfigured
            : TutorUnavailableReason.backendError,
      );
    } catch (_) {
      throw const TutorUnavailable(TutorUnavailableReason.offline);
    }

    final data = response.data;
    if (data is! Map || data['reply'] is! String) {
      throw const TutorUnavailable(TutorUnavailableReason.backendError);
    }

    final correction = data['correction'];
    return _TutorReply(
      content: data['reply'] as String,
      translation: data['translation'] as String?,
      correction: correction is Map
          ? TutorCorrection.fromJson(correction.cast<String, dynamic>())
          : null,
    );
  }

  Future<TutorMessage> _store(
    String conversationId,
    TutorRole role,
    String content, {
    String? translation,
    TutorCorrection? correction,
  }) async {
    final row = await _client
        .from('tutor_messages')
        .insert({
          'conversation_id': conversationId,
          'user_id': _uid,
          'role': role == TutorRole.user ? 'user' : 'tutor',
          'content': content,
          'translation': translation,
          // A correction that says nothing is not stored, so the UI never has
          // to render an empty one.
          'correction': correction != null && correction.isUsable
              ? correction.toJson()
              : null,
        })
        .select()
        .single();
    return TutorMessage.fromJson(row);
  }

  // ── Learner context (US-091) ──────────────────────────────────────────────

  /// Assemble what the tutor is told about this learner.
  ///
  /// Every field comes from recorded data: the level and goals they chose, the
  /// items they have actually studied, and the items they have actually got
  /// wrong. Nothing is estimated.
  Future<TutorContext> buildContext({
    required TargetLanguage language,
    required ProficiencyLevel level,
    required List<String> goals,
    String? scenario,
  }) async {
    final states = await _client
        .from('user_items')
        .select('item_type, item_id, incorrect_count, correct_count')
        .eq('user_id', _uid)
        .eq('language', language.code)
        .order('updated_at', ascending: false)
        .limit(300);

    final vocabIds = <String>[];
    final grammarIds = <String>[];
    final strugglingIds = <String>[];
    for (final row in states) {
      final id = row['item_id'] as String;
      switch (row['item_type']) {
        case 'vocabulary':
          if (vocabIds.length < _vocabularyContextSize) vocabIds.add(id);
        case 'grammar':
          grammarIds.add(id);
      }
      final wrong = (row['incorrect_count'] as num?)?.toInt() ?? 0;
      final right = (row['correct_count'] as num?)?.toInt() ?? 0;
      if (wrong > right && strugglingIds.length < _mistakeContextSize) {
        strugglingIds.add(id);
      }
    }

    final results = await Future.wait([
      _vocabularyWords(vocabIds),
      _grammarNames(grammarIds),
      _vocabularyWords(strugglingIds),
    ]);

    return TutorContext(
      language: language,
      level: level,
      goals: goals,
      vocabulary: results[0],
      grammar: results[1],
      recentMistakes: results[2],
      scenario: scenario,
    );
  }

  Future<List<String>> _vocabularyWords(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('vocabulary')
        .select('word, translation')
        .inFilter('id', ids);
    return [
      for (final row in rows) '${row['word']} (${row['translation']})',
    ];
  }

  Future<List<String>> _grammarNames(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('grammar_points')
        .select('name, meaning')
        .inFilter('id', ids);
    return [
      for (final row in rows) '${row['name']} — ${row['meaning']}',
    ];
  }
}

class _TutorReply {
  const _TutorReply({
    required this.content,
    this.translation,
    this.correction,
  });

  final String content;
  final String? translation;
  final TutorCorrection? correction;
}
