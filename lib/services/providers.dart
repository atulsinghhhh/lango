import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';
import '../models/insights.dart';
import '../models/language.dart';
import '../models/profile.dart';
import '../models/user_item.dart';
import 'auth_service.dart';
import 'comparison_service.dart';
import 'content_service.dart';
import 'history_service.dart';
import 'insights_service.dart';
import 'learn/starter_track.dart';
import 'learn/starter_track_service.dart';
import 'profile_service.dart';
import 'progress_service.dart';
import 'recommend/recommendation_engine.dart';
import 'review_service.dart';
import 'search_service.dart';
import 'session_service.dart';
import 'speaking_service.dart';
import 'speech_service.dart';
import 'srs/srs_engine.dart';
import 'tts/tts_api_client.dart';
import 'tts_service.dart';
import 'tutor_service.dart';

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

/// Speech playback, backed by the Lango TTS service with an on-device
/// fallback. Disposed with the container so the audio player is released.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService(
    api: TtsApiClient(
      baseUrl: Env.ttsApiBaseUrl,
      accessToken: () =>
          ref.read(supabaseProvider).auth.currentSession?.accessToken,
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});

final searchServiceProvider =
    Provider((ref) => SearchService(ref.watch(supabaseProvider)));

final insightsServiceProvider =
    Provider((ref) => InsightsService(ref.watch(supabaseProvider)));

final historyServiceProvider =
    Provider((ref) => HistoryService(ref.watch(supabaseProvider)));

final comparisonServiceProvider =
    Provider((ref) => ComparisonService(ref.watch(supabaseProvider)));

final speakingServiceProvider =
    Provider((ref) => SpeakingService(ref.watch(supabaseProvider)));

final tutorServiceProvider =
    Provider((ref) => TutorService(ref.watch(supabaseProvider)));

/// One recogniser for the app: the platform allows a single listen session at
/// a time, and a per-screen instance would fight over the microphone.
final speechServiceProvider = Provider((ref) => SpeechService());

final recommendationEngineProvider =
    Provider((ref) => const RecommendationEngine());

final starterTrackServiceProvider =
    Provider((ref) => StarterTrackService(ref.watch(supabaseProvider)));

final starterTrackEngineProvider = Provider((ref) => const StarterTrack());

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


/// Weak areas for a language (US-100).
final weakAreasProvider =
    FutureProvider.autoDispose.family<List<WeakArea>, String>(
        (ref, language) async {
  return ref.watch(insightsServiceProvider).weakAreas(language);
});

/// Everything the recommendation engine is allowed to see, assembled from
/// recorded data (US-101).
final learnerSnapshotProvider =
    FutureProvider.autoDispose.family<LearnerSnapshot, String>(
        (ref, language) async {
  final profile = await ref.watch(profileProvider.future);
  final target = TargetLanguage.fromCode(language);
  final userLanguage = profile?.languages
      .cast<UserLanguage?>()
      .firstWhere((l) => l?.language == target, orElse: () => null);

  final reviews = ref.watch(reviewServiceProvider);
  final content = ref.watch(contentServiceProvider);
  final sessions = ref.watch(sessionServiceProvider);
  final insights = ref.watch(insightsServiceProvider);

  final weekAgo = DateTime.now().subtract(const Duration(days: 7));

  final results = await Future.wait([
    reviews.dueCount(language: language),
    content.vocabularyCount(language),
    content.charactersCount(language),
    reviews.statesFor(language),
    sessions.secondsStudiedToday(),
    ref.watch(weakAreasProvider(language).future),
    insights.skillsPractisedSince(language, weekAgo),
  ]);

  final states = (results[3] as List).cast<UserItem>();
  final trackedVocabulary =
      states.where((s) => s.itemType == 'vocabulary').length;
  final trackedCharacters =
      states.where((s) => s.itemType == 'character').length;
  final secondsToday = (results[4] as Map<String, int>)[language] ?? 0;
  final vocabularyTotal = results[1] as int;

  return LearnerSnapshot(
    language: target,
    level: userLanguage?.level ?? ProficiencyLevel.beginner,
    goals: userLanguage?.goals ?? const [],
    dueReviews: results[0] as int,
    untrackedVocabulary:
        (vocabularyTotal - trackedVocabulary).clamp(0, vocabularyTotal),
    charactersTracked: trackedCharacters,
    charactersAvailable: results[2] as int,
    minutesStudiedToday: (secondsToday / 60).round(),
    dailyGoalMinutes: profile?.dailyGoalMinutes ?? 10,
    weakAreas: results[5] as List<WeakArea>,
    skillsPractisedThisWeek: results[6] as Set<String>,
  );
});

/// The single next activity to suggest (US-101).
final recommendationProvider =
    FutureProvider.autoDispose.family<Recommendation, String>(
        (ref, language) async {
  final snapshot = await ref.watch(learnerSnapshotProvider(language).future);
  return ref.watch(recommendationEngineProvider).recommend(snapshot);
});

/// The guided beginner path for a language, or null when the learner is not
/// its audience.
///
/// Null rather than an empty plan, so the Learn hub has one thing to check:
/// an intermediate learner gets no card, and neither does a beginner studying
/// a language whose catalog has no writing system yet.
final starterTrackProvider =
    FutureProvider.autoDispose.family<StarterTrackPlan?, String>(
        (ref, language) async {
  final profile = await ref.watch(profileProvider.future);
  final target = TargetLanguage.fromCode(language);
  final userLanguage = profile?.languages
      .cast<UserLanguage?>()
      .firstWhere((l) => l?.language == target, orElse: () => null);
  if (userLanguage == null) return null;

  final snapshot =
      await ref.watch(starterTrackServiceProvider).snapshot(userLanguage);
  if (!snapshot.wantsGuidance) return null;

  final plan = ref.watch(starterTrackEngineProvider).plan(snapshot);
  return plan.isEmpty ? null : plan;
});
