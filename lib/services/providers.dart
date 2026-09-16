import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/language.dart';
import '../models/profile.dart';
import 'auth_service.dart';
import 'content_service.dart';
import 'profile_service.dart';
import 'progress_service.dart';
import 'review_service.dart';
import 'session_service.dart';
import 'srs/srs_engine.dart';
import 'tts_service.dart';

final supabaseProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authServiceProvider =
    Provider((ref) => AuthService(ref.watch(supabaseProvider)));

final profileServiceProvider =
    Provider((ref) => ProfileService(ref.watch(supabaseProvider)));

final contentServiceProvider =
    Provider((ref) => ContentService(ref.watch(supabaseProvider)));

final srsEngineProvider = Provider((ref) => SrsEngine());

final reviewServiceProvider = Provider((ref) =>
    ReviewService(ref.watch(supabaseProvider), ref.watch(srsEngineProvider)));

final sessionServiceProvider =
    Provider((ref) => SessionService(ref.watch(supabaseProvider)));

final progressServiceProvider =
    Provider((ref) => ProgressService(ref.watch(supabaseProvider)));

final ttsServiceProvider = Provider((ref) => TtsService());

/// Current profile incl. selected languages. Invalidate after onboarding or
/// settings changes.
final profileProvider = FutureProvider<Profile?>((ref) async {
  final auth = ref.watch(authServiceProvider);
  if (auth.currentUser == null) return null;
  return ref.watch(profileServiceProvider).fetchProfile();
});

/// The language the learner is currently studying (REDESIGN.md §12).
///
/// One global selection drives lessons, vocabulary, grammar, reviews, tutor
/// and progress, so switching language is a single obvious action rather than
/// a `?lang=` parameter threaded through every route.
///
/// `null` means "not yet resolved" — read [effectiveLanguageProvider] instead,
/// which falls back to the learner's first onboarded language.
final activeLanguageProvider =
    NotifierProvider<ActiveLanguage, TargetLanguage?>(ActiveLanguage.new);

class ActiveLanguage extends Notifier<TargetLanguage?> {
  @override
  TargetLanguage? build() => null;

  void select(TargetLanguage language) => state = language;
}

/// The language to actually use: the explicit selection when there is one,
/// otherwise the learner's first onboarded language.
final effectiveLanguageProvider = Provider<TargetLanguage?>((ref) {
  final selected = ref.watch(activeLanguageProvider);
  if (selected != null) return selected;
  final profile = ref.watch(profileProvider).value;
  final langs = profile?.languages ?? const [];
  return langs.isEmpty ? null : langs.first.language;
});
