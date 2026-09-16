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
}
