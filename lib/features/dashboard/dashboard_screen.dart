import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
import '../../models/profile.dart';
import '../../services/providers.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/language_switcher.dart';

class DashboardData {
  const DashboardData({required this.dueByLanguage, required this.secondsToday});

  final Map<String, int> dueByLanguage;
  final Map<String, int> secondsToday;

  int get totalDue => dueByLanguage.values.fold(0, (a, b) => a + b);
}

/// Keyed by a comma-joined list of language codes rather than a `List<String>`:
/// family arguments are compared with `==`, and a fresh list instance on every
/// build would key a brand-new autoDispose provider each time, leaving the
/// dashboard stuck in `loading` forever.
final dashboardDataProvider =
    FutureProvider.autoDispose.family<DashboardData, String>(
        (ref, languageCodesKey) async {
  final languageCodes =
      languageCodesKey.isEmpty ? <String>[] : languageCodesKey.split(',');
  final reviews = ref.watch(reviewServiceProvider);
  final sessions = ref.watch(sessionServiceProvider);
  final due = <String, int>{};
  for (final code in languageCodes) {
    due[code] = await reviews.dueCount(language: code);
  }
  final seconds = await sessions.secondsStudiedToday();
  return DashboardData(dueByLanguage: due, secondsToday: seconds);
});

/// Dashboard (REDESIGN.md §11).
///
/// Its one job is to tell the learner what to do next, so the "continue"
/// action is the first and largest thing on the screen — not a statistics
/// wall. Priority order: continue → today's activity → recommended → progress.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codes = profile.languages.map((l) => l.language.code).join(',');
    final data = ref.watch(dashboardDataProvider(codes));
    final active = ref.watch(effectiveLanguageProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardDataProvider(codes)),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  LangoSpace.gutter,
                  LangoSpace.md,
                  LangoSpace.gutter,
                  LangoSpace.xxl,
                ),
                children: [
                  _Header(profile: profile),
                  const Gap.xl(),
                  if (profile.languages.length > 1) ...[
                    LanguageSwitcher(languages: profile.languages),
                    const Gap.xl(),
                  ],
                  data.when(
                    loading: () => const _DashboardSkeleton(),
                    error: (_, _) => LangoError(
                      message:
                          "We couldn't load today's plan. Check your connection.",
                      onRetry: () =>
                          ref.invalidate(dashboardDataProvider(codes)),
                    ),
                    data: (d) => _DashboardBody(
                      profile: profile,
                      data: d,
                      active: active,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Wordmark instead of a greeting: the learner opens this screen to
        // find the next action, not to be greeted.
        Expanded(child: Text('Lango', style: LangoType.h2)),
        // Profile lives behind the avatar, mirroring the reference's
        // top-right avatar (REDESIGN.md §10).
        Semantics(
          button: true,
          label: 'Profile and settings',
          child: InkWell(
            onTap: () => context.push('/settings'),
            customBorder: const CircleBorder(),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: LangoPalette.tintPink,
              ),
              child: const Icon(Icons.person_rounded,
                  color: LangoColors.primaryDeep, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LangoSkeleton(height: 150, radius: LangoRadius.xl),
        Gap.card(),
        LangoSkeleton(height: 100, radius: LangoRadius.xl),
        Gap.card(),
        LangoSkeleton(height: 100, radius: LangoRadius.xl),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.profile,
    required this.data,
    required this.active,
  });

  final Profile profile;
  final DashboardData data;
  final TargetLanguage? active;

  @override
  Widget build(BuildContext context) {
    final lang = active ?? profile.languages.first.language;
    final minutesToday = ((data.secondsToday[lang.code] ?? 0) / 60).round();
    final goal = profile.dailyGoalMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Continue learning — the single most important element.
        _ContinueCard(data: data, profile: profile, language: lang),
        const Gap.card(),

        // 2. Today's activity.
        _TodayCard(minutes: minutesToday, goal: goal, language: lang),
        const Gap.card(),

        // 3. Recommended activity.
        Text('Recommended', style: LangoType.h3),
        const Gap.md(),
        _RecommendationCard(language: lang, due: data.dueByLanguage[lang.code] ?? 0),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.data,
    required this.profile,
    required this.language,
  });

  final DashboardData data;
  final Profile profile;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    final due = data.totalDue;
    final hasDue = due > 0;

    final headline = hasDue
        ? '$due ${due == 1 ? 'review' : 'reviews'} due'
        : 'Start today’s session';
    final sub = hasDue
        ? 'Clear these first — they are scheduled for right now.'
        : 'A short mix of vocabulary, grammar and listening.';

    // Overdue reviews take priority, otherwise start a fresh session in the
    // language with the least study time today (US-011).
    final target = hasDue
        ? '/review?lang=${data.dueByLanguage.entries.reduce((a, b) => a.value >= b.value ? a : b).key}'
        : '/session?lang=${language.code}';

    return LangoCard.tinted(
      tint: LangoColors.tints.first,
      padding: const EdgeInsets.all(LangoSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LanguageBadge(language: language),
              const Spacer(),
              Text('CONTINUE', style: LangoType.caption),
            ],
          ),
          const Gap.md(),
          Text(headline, style: LangoType.h2),
          const SizedBox(height: 4),
          Text(sub,
              style: LangoType.body
                  .copyWith(color: LangoColors.foregroundSecondary)),
          const Gap.lg(),
          FilledButton.icon(
            onPressed: () => context.push(target),
            icon: Icon(hasDue ? Icons.replay_rounded : Icons.play_arrow_rounded),
            label: Text(hasDue ? 'Review now' : 'Start session'),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.minutes,
    required this.goal,
    required this.language,
  });

  final int minutes;
  final int goal;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    final progress = goal == 0 ? 0.0 : (minutes / goal).clamp(0.0, 1.0);
    final met = minutes >= goal;

    return LangoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('TODAY', style: LangoType.caption),
              const Spacer(),
              Text(
                met ? 'Goal met 🎉' : '$minutes / $goal min',
                style: LangoType.label.copyWith(
                  color: met ? LangoColors.success : LangoColors.foreground,
                ),
              ),
            ],
          ),
          const Gap.sm(),
          ClipRRect(
            borderRadius: BorderRadius.circular(LangoRadius.sm),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              // The card fill is already `surfaceMuted`, so the theme's
              // default track would be invisible against it.
              backgroundColor: LangoPalette.white,
              color: met ? LangoColors.success : LangoColors.primary,
              semanticsLabel: 'Daily goal progress',
              semanticsValue: '$minutes of $goal minutes',
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.language, required this.due});

  final TargetLanguage language;
  final int due;

  @override
  Widget build(BuildContext context) {
    // Recommend the thing that is not already covered by the primary CTA.
    final (title, sub, icon, route) = due > 0
        ? (
            'Learn new words',
            'Add to your deck once reviews are clear',
            Icons.style_rounded,
            '/learn/flashcards?lang=${language.code}',
          )
        : (
            'Practise listening',
            'Train your ear on words you know',
            Icons.headphones_rounded,
            '/learn/listening?lang=${language.code}',
          );

    return LangoCard.tinted(
      tint: LangoColors.tints[2],
      onTap: () => context.push(route),
      semanticLabel: '$title. $sub',
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: LangoPalette.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: LangoColors.primaryDeep, size: 24),
          ),
          const SizedBox(width: LangoSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: LangoType.h3),
                const SizedBox(height: 2),
                Text(sub,
                    style: LangoType.body.copyWith(
                      fontSize: 14,
                      color: LangoColors.foregroundSecondary,
                    )),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded,
              color: LangoColors.primaryDeep, size: 22),
        ],
      ),
    );
  }
}
