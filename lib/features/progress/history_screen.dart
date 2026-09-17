import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
import '../../services/history_service.dart';
import '../../services/providers.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';

final historyProvider = FutureProvider.autoDispose
    .family<List<HistoryDay>, ({String language, int days})>((ref, key) async {
  return ref
      .watch(historyServiceProvider)
      .recent(language: key.language, days: key.days);
});

/// Learning history (US-111).
///
/// Sessions, reviews, exercises, speaking attempts and study time, by day,
/// assembled from the immutable event log rather than a stored summary — so
/// what it shows is what actually happened.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _days = 30;

  static const _windows = <int>[7, 30, 90];

  @override
  Widget build(BuildContext context) {
    final key = (language: widget.language.code, days: _days);
    final history = ref.watch(historyProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: LangoSpace.md),
            child: Center(
              child: Text(widget.language.flag,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LangoSpace.gutter,
                    LangoSpace.sm,
                    LangoSpace.gutter,
                    0,
                  ),
                  child: Row(
                    children: [
                      for (final window in _windows) ...[
                        ChoiceChip(
                          label: Text('$window days'),
                          selected: _days == window,
                          onSelected: (_) => setState(() => _days = window),
                        ),
                        const SizedBox(width: LangoSpace.xs),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(historyProvider(key)),
                    child: history.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(LangoSpace.gutter),
                        child: LangoSkeletonList(count: 3),
                      ),
                      error: (_, _) => Padding(
                        padding: const EdgeInsets.all(LangoSpace.gutter),
                        child: LangoError(
                          message: "We couldn't load your history. "
                              'Check your connection.',
                          onRetry: () => ref.invalidate(historyProvider(key)),
                        ),
                      ),
                      data: (days) {
                        final active =
                            days.where((d) => !d.isEmpty).toList();
                        if (active.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.all(LangoSpace.gutter),
                            children: const [
                              LangoEmpty(
                                icon: Icons.history_rounded,
                                title: 'Nothing recorded yet',
                                message: 'Study a session and it will show up '
                                    'here with the date and what you covered.',
                              ),
                            ],
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(
                            LangoSpace.gutter,
                            LangoSpace.md,
                            LangoSpace.gutter,
                            LangoSpace.xxl,
                          ),
                          children: [
                            _Totals(days: active),
                            const Gap.xl(),
                            for (final day in active) ...[
                              _DayCard(day: day),
                              const Gap.md(),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.days});

  final List<HistoryDay> days;

  @override
  Widget build(BuildContext context) {
    var minutes = 0;
    var reviews = 0;
    var exercises = 0;
    var speaking = 0;
    for (final day in days) {
      minutes += day.minutes;
      reviews += day.reviews;
      exercises += day.exercises;
      speaking += day.speakingAttempts;
    }

    return LangoCard.tinted(
      tint: LangoColors.tints.first,
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('IN THIS PERIOD', style: LangoType.caption),
          const Gap.sm(),
          Text(
            '$minutes ${minutes == 1 ? 'minute' : 'minutes'} studied across '
            '${days.length} ${days.length == 1 ? 'day' : 'days'}',
            style: LangoType.h3,
          ),
          const Gap.xs(),
          Text(
            '$reviews reviews · $exercises exercises'
            '${speaking > 0 ? ' · $speaking speaking attempts' : ''}',
            style: LangoType.bodyMuted,
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final HistoryDay day;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _dateLabel {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final difference = midnight.difference(day.date).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${day.date.day} ${_months[day.date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = day.reviewAccuracyPercent;

    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(_dateLabel, style: LangoType.label)),
              if (day.minutes > 0)
                Text('${day.minutes} min', style: LangoType.caption),
            ],
          ),
          const Gap.sm(),
          Wrap(
            spacing: LangoSpace.sm,
            runSpacing: LangoSpace.xs,
            children: [
              if (day.sessions.isNotEmpty)
                _Chip(
                  icon: Icons.play_circle_outline_rounded,
                  label: '${day.sessions.length} '
                      '${day.sessions.length == 1 ? 'session' : 'sessions'}',
                ),
              if (day.reviews > 0)
                _Chip(
                  icon: Icons.replay_rounded,
                  label: '${day.reviews} reviews'
                      '${accuracy != null ? ' · $accuracy%' : ''}',
                ),
              if (day.exercises > 0)
                _Chip(
                  icon: Icons.checklist_rounded,
                  label: '${day.exercises} exercises',
                ),
              if (day.speakingAttempts > 0)
                _Chip(
                  icon: Icons.mic_rounded,
                  label: '${day.speakingAttempts} spoken',
                ),
            ],
          ),
          // Skills come from the session record, so they describe what was
          // actually practised rather than what was scheduled.
          if (day.sessions.any((s) => s.skills.isNotEmpty)) ...[
            const Gap.sm(),
            Text(
              {
                for (final session in day.sessions) ...session.skills,
              }.join(' · '),
              style: LangoType.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: LangoColors.primaryDeep),
        const SizedBox(width: 4),
        Text(label, style: LangoType.bodyMuted.copyWith(fontSize: 14)),
      ],
    );
  }
}
