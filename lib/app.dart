import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/dashboard/home_gate.dart';
import 'features/learn/learn_hub_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/speaking/speaking_screen.dart';
import 'features/tutor/tutor_screen.dart';
import 'features/grammar/grammar_detail_screen.dart';
import 'features/grammar/grammar_list_screen.dart';
import 'features/listening/listening_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/review/review_screen.dart';
import 'features/session/session_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/vocabulary/exercise_screen.dart';
import 'features/vocabulary/flashcard_screen.dart';
import 'features/vocabulary/vocab_list_screen.dart';
import 'features/writing/character_practice_screen.dart';
import 'features/writing/characters_screen.dart';
import 'models/language.dart';

class LangoApp extends ConsumerWidget {
  const LangoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'Lango',
      theme: buildTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = Supabase.instance.client.auth;
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _StreamListenable(auth.onAuthStateChange),
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      final onAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),

      // Persistent navigation shell (REDESIGN.md §10). Each branch keeps its
      // own navigation stack, so switching tabs preserves where you were.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeGate()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/learn',
              builder: (_, _) => const LearnHubScreen(),
              routes: [
                GoRoute(
                  path: 'vocabulary',
                  builder: (_, state) => VocabListScreen(language: _lang(state)),
                ),
                GoRoute(
                  path: 'grammar',
                  builder: (_, state) =>
                      GrammarListScreen(language: _lang(state)),
                ),
                GoRoute(
                  path: 'writing',
                  builder: (_, state) => CharactersScreen(language: _lang(state)),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/review',
              builder: (_, state) => ReviewScreen(
                  language: state.uri.queryParameters['lang'] != null
                      ? _lang(state)
                      : null),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/tutor', builder: (_, _) => const TutorScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
          ]),
        ],
      ),

      // Focused, one-task-at-a-time flows live outside the shell so nothing
      // competes with the task (REDESIGN.md §13).
      GoRoute(
        path: '/learn/flashcards',
        builder: (_, state) => FlashcardScreen(language: _lang(state)),
      ),
      GoRoute(
        path: '/learn/exercises',
        builder: (_, state) => ExerciseScreen(language: _lang(state)),
      ),
      GoRoute(
        path: '/learn/grammar/detail',
        builder: (_, state) => GrammarDetailScreen(point: state.extra as dynamic),
      ),
      GoRoute(
        path: '/learn/writing/practice',
        builder: (_, state) =>
            CharacterPracticeScreen(character: state.extra as dynamic),
      ),
      GoRoute(
        path: '/learn/listening',
        builder: (_, state) => ListeningScreen(language: _lang(state)),
      ),
      GoRoute(
        path: '/speaking',
        builder: (_, state) => SpeakingScreen(language: _lang(state)),
      ),
      GoRoute(
        path: '/session',
        builder: (_, state) => SessionScreen(language: _lang(state)),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
});

TargetLanguage _lang(GoRouterState state) =>
    TargetLanguage.fromCode(state.uri.queryParameters['lang'] ?? 'ko');

class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
