import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/language.dart';
import '../models/profile.dart';

class ProfileService {
  ProfileService(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<Profile?> fetchProfile() async {
    final row = await _client
        .from('profiles')
        .select('*, user_languages(*)')
        .eq('id', _uid)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  /// Persist the onboarding result: selected languages, per-language level,
  /// goals and daily goal (US-004/005/006).
  Future<void> completeOnboarding({
    required Map<TargetLanguage, ProficiencyLevel> languages,
    required List<String> goals,
    required int dailyGoalMinutes,
  }) async {
    assert(languages.isNotEmpty, 'At least one language must be selected');
    await _client.from('profiles').upsert({
      'id': _uid,
      'onboarding_complete': true,
      'daily_goal_minutes': dailyGoalMinutes,
    });
    // Replace language selection wholesale; learning history lives elsewhere
    // and is never deleted here (US-150).
    await _client.from('user_languages').delete().eq('user_id', _uid);
    await _client.from('user_languages').insert([
      for (final entry in languages.entries)
        {
          'user_id': _uid,
          'language': entry.key.code,
          'level': entry.value.code,
          'goals': goals,
        }
    ]);
  }

  Future<void> updateDailyGoal(int minutes) async {
    await _client
        .from('profiles')
        .update({'daily_goal_minutes': minutes}).eq('id', _uid);
  }

  // ── Changing preferences later (US-150) ────────────────────────────────────
  //
  // These are granular on purpose. [completeOnboarding] replaces the language
  // selection wholesale, which is right for onboarding and wrong afterwards:
  // changing a level should not silently reset the learner's goals. None of
  // these touch `user_items`, `review_events`, `exercise_attempts` or
  // `learning_sessions`, so learning history survives every preference change
  // (US-150: history is not deleted unless explicitly requested).

  /// Change the level for one language (US-150).
  Future<void> updateLevel(TargetLanguage language, ProficiencyLevel level) async {
    await _client
        .from('user_languages')
        .update({'level': level.code})
        .eq('user_id', _uid)
        .eq('language', language.code);
  }

  /// Change the goals for one language (US-006, US-150).
  Future<void> updateGoals(TargetLanguage language, List<String> goals) async {
    await _client
        .from('user_languages')
        .update({'goals': goals})
        .eq('user_id', _uid)
        .eq('language', language.code);
  }

  /// Add a language the learner was not studying before (US-150).
  ///
  /// Upsert rather than insert: re-adding a language the learner previously
  /// removed restores the row, and their history for it — which was never
  /// deleted — becomes visible again.
  Future<void> addLanguage(
    TargetLanguage language,
    ProficiencyLevel level, {
    List<String> goals = const [],
  }) async {
    await _client.from('user_languages').upsert({
      'user_id': _uid,
      'language': language.code,
      'level': level.code,
      'goals': goals,
    });
  }

  /// Stop studying a language (US-150).
  ///
  /// Removes only the selection. Every recorded review, attempt and session
  /// for that language stays exactly where it is.
  Future<void> removeLanguage(TargetLanguage language) async {
    await _client
        .from('user_languages')
        .delete()
        .eq('user_id', _uid)
        .eq('language', language.code);
  }
}
