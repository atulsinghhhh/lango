import 'package:supabase_flutter/supabase_flutter.dart';

import 'speech/speech_comparison.dart';

/// Persists speaking attempts (US-080 "Attempt is saved", US-081).
///
/// The row records what was targeted, what the recogniser transcribed, and how
/// the two compare. It deliberately records no pronunciation score, because
/// nothing in this app can measure one.
class SpeakingService {
  SpeakingService(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<void> record({
    required String language,
    required String targetText,
    required String recognizedText,
    required SpeechComparison comparison,
    double? recognitionConfidence,
    String? itemType,
    String? itemId,
  }) async {
    await _client.from('speaking_attempts').insert({
      'user_id': _uid,
      'language': language,
      'item_type': itemType,
      'item_id': itemId,
      'target_text': targetText,
      'recognized_text': recognizedText,
      'recognition_confidence': recognitionConfidence,
      'match_ratio': comparison.matchRatio,
      'missing_words': comparison.missing,
      'extra_words': comparison.extra,
    });
  }

  /// Recent attempts for the history and progress screens.
  Future<List<Map<String, dynamic>>> recent(String language,
      {int limit = 30}) async {
    return await _client
        .from('speaking_attempts')
        .select()
        .eq('user_id', _uid)
        .eq('language', language)
        .order('created_at', ascending: false)
        .limit(limit);
  }
}
