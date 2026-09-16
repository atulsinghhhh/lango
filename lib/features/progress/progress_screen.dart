import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
import '../../models/profile.dart';
import '../../services/progress_service.dart';
import '../../services/providers.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/language_switcher.dart';

final languageProgressProvider = FutureProvider.autoDispose
    .family<LanguageProgress, String>((ref, language) async {
  return ref.watch(progressServiceProvider).forLanguage(language);
});

/// Everything on this screen is derived from data the app actually records —
/// `review_events`, `learning_sessions` and `user_items`. Nothing is
/// estimated, and no metric is shown that the system cannot measure
/// (CLAUDE.md invariant; REDESIGN.md §19, §25).
class LearningStats {
  const LearningStats({
    required this.minutesThisWeek,
    required this.itemsReviewed,
    required this.correct,
    required this.streakDays,
    required this.tracked,
    required this.mastered,
  });

  final int minutesThisWeek;
  final int itemsReviewed;
  final int correct;
  final int streakDays;
  final int tracked;
  final int mastered;

  /// Null when nothing has been reviewed — an accuracy of "0%" would be a lie.
  int? get accuracyPercent =>
      itemsReviewed == 0 ? null : (correct / itemsReviewed * 100).round();
}

final learningStatsProvider =
    FutureProvider.autoDispose.family<LearningStats, String>(
        (ref, language) async {
  final sessions = ref.watch(sessionServiceProvider);
  final reviews = ref.watch(reviewServiceProvider);

  final weekAgo = DateTime.now().subtract(const Duration(days: 7));
  final activity = await sessions.activitySince(weekAgo);
  final recent = await sessions.recentSessions(limit: 60);
  final states = await reviews.statesFor(language);

  // Minutes studied in this language over the last 7 days.
  var seconds = 0;
  final studyDays = <String>{};
  for (final row in recent) {
    if (row['language'] != language) continue;
    final started = DateTime.tryParse(row['started_at'] as String? ?? '');
    if (started == null) continue;
    final local = started.toLocal();
    studyDays.add('${local.year}-${local.month}-${local.day}');
    if (local.isAfter(weekAgo)) {
      seconds += (row['duration_seconds'] as num?)?.toInt() ?? 0;
    }
  }

  // Consecutive days up to today (or yesterday, so an unfinished day does not
  // break a run the learner has not lost yet).
  var streak = 0;
  var cursor = DateTime.now();
  String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  if (!studyDays.contains(key(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  while (studyDays.contains(key(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return LearningStats(
    minutesThisWeek: (seconds / 60).round(),
    itemsReviewed: activity.items,
    correct: activity.correct,
    streakDays: streak,
    tracked: states.length,
    mastered: states.where((s) => s.status == 'mastered').length,
  );
});

/// Progress (REDESIGN.md §22, §25).
///
/// Statistics first — what the learner has actually done this week — then a
/// compact skill map. Deliberately not a wall of percentage bars, and
/// deliberately less prominent than the learning screens themselves.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final active = ref.watch(effectiveLanguageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
            child: profile.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(LangoSpace.gutter),
                child: LangoSkeletonList(count: 2),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(LangoSpace.gutter),
                child: LangoError(
                  message: "We couldn't load your progress. "
                      'Check your connection.',
                  onRetry: () => ref.invalidate(profileProvider),
                ),
              ),
              data: (p) => _body(context, ref, p, active),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    Profile? p,
    TargetLanguage? active,
  ) {
    if (p == null || p.languages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(LangoSpace.gutter),
        child: LangoEmpty(
          icon: Icons.insights_outlined,
          title: 'Nothing to show yet',
          message: 'Finish onboarding and study a few words — your progress '
              'will appear here.',
        ),
      );
    }

    final lang = active ?? p.languages.first.language;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(learningStatsProvider(lang.code));
        ref.invalidate(languageProgressProvider(lang.code));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          LangoSpace.gutter,
          LangoSpace.md,
          LangoSpace.gutter,
          LangoSpace.xxl,
        ),
        children: [
          if (p.languages.length > 1) ...[
            LanguageSwitcher(languages: p.languages),
            const Gap.xl(),
          ],
          _StatsSection(language: lang),
          const Gap.xxl(),
          Text('Skills', style: LangoType.h3),
          const Gap.md(),
          _SkillMap(language: lang),
        ],
      ),
    );
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection({required this.language});

  final TargetLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(learningStatsProvider(language.code));

    return stats.when(
      loading: () =>
          const LangoSkeleton(height: 190, radius: LangoRadius.xl),
      error: (e, _) => LangoError(
        message: "We couldn't load your statistics.",
        onRetry: () => ref.invalidate(learningStatsProvider(language.code)),
      ),
      data: (s) {
        if (s.itemsReviewed == 0 && s.tracked == 0) {
          return const LangoEmpty(
            icon: Icons.timeline_rounded,
            title: 'No activity yet',
            message: 'Study your first words and your statistics will start '
                'filling in here.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('LAST 7 DAYS', style: LangoType.caption),
            const Gap.md(),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    value: '${s.minutesThisWeek}',
                    unit: 'min',
                    label: 'Studied',
                    tint: LangoColors.tints[0],
                  ),
                ),
                const SizedBox(width: LangoSpace.sm),
                Expanded(
                  child: _StatTile(
                    value: '${s.itemsReviewed}',
                    label: 'Reviewed',
                    tint: LangoColors.tints[1],
                  ),
                ),
              ],
            ),
            const Gap.sm(),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    // Null rather than a fabricated 0% when nothing is graded.
                    value: s.accuracyPercent == null
                        ? '—'
                        : '${s.accuracyPercent}',
                    unit: s.accuracyPercent == null ? null : '%',
                    label: 'Accuracy',
                    tint: LangoColors.tints[2],
                  ),
                ),
                const SizedBox(width: LangoSpace.sm),
                Expanded(
                  child: _StatTile(
                    value: '${s.streakDays}',
                    unit: s.streakDays == 1 ? 'day' : 'days',
                    label: 'Streak',
                    tint: LangoColors.tints[3],
                  ),
                ),
              ],
            ),
            const Gap.lg(),
            LangoCard(
              padding: const EdgeInsets.all(LangoSpace.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Words and patterns tracked',
                        style: LangoType.body),
                  ),
                  Text('${s.mastered} / ${s.tracked}',
                      style: LangoType.label),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.tint,
    this.unit,
  });

  final String value;
  final String? unit;
  final String label;
  final LangoTint tint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value ${unit ?? ''}',
      child: Container(
        padding: const EdgeInsets.all(LangoSpace.lg),
        decoration: BoxDecoration(
          borderRadius: LangoRadius.xlAll,
          gradient: tint.gradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value, style: LangoType.h1),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 3),
                  Text(unit!,
                      style: LangoType.label
                          .copyWith(color: LangoColors.foregroundSecondary)),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(label.toUpperCase(), style: LangoType.caption),
          ],
        ),
      ),
    );
  }
}

class _SkillMap extends ConsumerWidget {
  const _SkillMap({required this.language});

  final TargetLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(languageProgressProvider(language.code));

    return progress.when(
      loading: () => const LangoSkeleton(height: 160, radius: LangoRadius.xl),
      error: (e, _) => LangoError(
        message: 'Your skill breakdown is unavailable right now.',
        onRetry: () => ref.invalidate(languageProgressProvider(language.code)),
      ),
      data: (lp) {
        if (lp.skills.isEmpty) {
          return const LangoEmpty(
            title: 'No skills tracked yet',
            message: 'Study a few items to start building this map.',
          );
        }
        return LangoCard(
          child: Column(
            children: [
              for (var i = 0; i < lp.skills.length; i++) ...[
                _SkillRow(skill: lp.skills[i]),
                if (i != lp.skills.length - 1) const Gap.md(),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill});

  final SkillProgress skill;

  @override
  Widget build(BuildContext context) {
    final pct = (skill.percent * 100).round();

    return Semantics(
      label: '${skill.skill}: $pct percent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_titleCase(skill.skill), style: LangoType.label),
              ),
              Text('$pct%',
                  style: LangoType.label
                      .copyWith(color: LangoColors.foregroundMuted)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(LangoRadius.sm),
            child: LinearProgressIndicator(
              value: skill.percent,
              minHeight: 10,
              // The card fill is already muted, so the default track would
              // disappear against it.
              backgroundColor: LangoPalette.white,
            ),
          ),
        ],
      ),
    );
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
