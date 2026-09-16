import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/lango_page.dart';
import '../../services/session_service.dart';
import '../listening/listening_screen.dart';
import '../review/review_screen.dart';
import '../vocabulary/exercise_screen.dart';
import '../vocabulary/flashcard_screen.dart';

class _SessionStep {
  _SessionStep(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.skill,
      required this.builder});

  final String title;
  final String subtitle;
  final IconData icon;
  final String skill;
  final Widget Function() builder;
  bool done = false;
}

/// Daily learning session (US-130/131): a guided sequence of activities.
/// The summary is derived from the immutable review-event log, and the
/// session itself is persisted.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  String? _sessionId;
  late final DateTime _startedAt;
  late final List<_SessionStep> _steps;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _steps = [
      _SessionStep(
        title: 'Review due items',
        subtitle: 'Refresh what you were about to forget',
        icon: Icons.replay,
        skill: 'review',
        builder: () => ReviewScreen(language: widget.language),
      ),
      _SessionStep(
        title: 'Learn vocabulary',
        subtitle: 'New words with flashcards',
        icon: Icons.style,
        skill: 'vocabulary',
        builder: () => FlashcardScreen(language: widget.language),
      ),
      _SessionStep(
        title: 'Practice exercises',
        subtitle: 'Multiple choice, typing, sentences',
        icon: Icons.quiz,
        skill: 'vocabulary',
        builder: () => ExerciseScreen(language: widget.language),
      ),
      _SessionStep(
        title: 'Listening',
        subtitle: 'Hear it, understand it',
        icon: Icons.headphones,
        skill: 'listening',
        builder: () => ListeningScreen(language: widget.language),
      ),
    ];
    _start();
  }

  Future<void> _start() async {
    try {
      final id = await ref
          .read(sessionServiceProvider)
          .startSession(widget.language.code);
      if (mounted) setState(() => _sessionId = id);
    } catch (_) {
      // Session tracking failing shouldn't block learning.
    }
  }

  Future<void> _openStep(_SessionStep step) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => step.builder()));
    setState(() => step.done = true);
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    final sessions = ref.read(sessionServiceProvider);
    ({int items, int correct, int incorrect}) activity =
        (items: 0, correct: 0, incorrect: 0);
    try {
      activity = await sessions.activitySince(_startedAt);
      if (_sessionId != null) {
        await sessions.completeSession(
          _sessionId!,
          SessionSummary(
            itemsStudied: activity.items,
            correct: activity.correct,
            incorrect: activity.incorrect,
            durationSeconds:
                DateTime.now().difference(_startedAt).inSeconds,
            skills: _steps
                .where((s) => s.done)
                .map((s) => s.skill)
                .toSet()
                .toList(),
          ),
        );
      }
    } catch (_) {
      // Still show the summary; the learning records themselves are saved.
    }
    final due = await ref.read(reviewServiceProvider).dueCount();
    if (!mounted) return;
    setState(() => _finishing = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session complete 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items studied: ${activity.items}'),
            Text('Correct: ${activity.correct}'),
            Text('Incorrect: ${activity.incorrect}'),
            Text(
                'Study time: ${DateTime.now().difference(_startedAt).inMinutes} min'),
            const SizedBox(height: 12),
            Text(due > 0
                ? 'Next: you still have $due reviews due.'
                : 'Next: come back tomorrow for your reviews!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final done = _steps.where((s) => s.done).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's session"),
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
                    LangoSpace.md,
                    LangoSpace.gutter,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(LangoRadius.sm),
                        child: LinearProgressIndicator(
                          value: _steps.isEmpty ? 0 : done / _steps.length,
                          minHeight: 8,
                          backgroundColor: LangoColors.surfaceMuted,
                          semanticsLabel: 'Session progress',
                        ),
                      ),
                      const Gap.xs(),
                      Text('$done OF ${_steps.length} ACTIVITIES DONE',
                          style: LangoType.caption),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      LangoSpace.gutter,
                      LangoSpace.lg,
                      LangoSpace.gutter,
                      LangoSpace.lg,
                    ),
                    itemCount: _steps.length,
                    separatorBuilder: (_, _) => const Gap.sm(),
                    itemBuilder: (context, i) {
                      final step = _steps[i];
                      final isCurrent = !step.done &&
                          _steps.take(i).every((s) => s.done);
                      return _SessionStepCard(
                        step: step,
                        current: isCurrent,
                        index: i,
                        onTap: () => _openStep(step),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LangoSpace.gutter,
                    0,
                    LangoSpace.gutter,
                    LangoSpace.lg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _steps.any((s) => s.done) && !_finishing ? _finish : null,
                      child: _finishing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: LangoColors.primaryForeground))
                          : const Text('Finish session'),
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

/// One activity in the daily session (REDESIGN.md §23).
///
/// The current activity is tinted and prominent; completed ones recede. The
/// learner can always see what is next without extra chrome.
class _SessionStepCard extends StatelessWidget {
  const _SessionStepCard({
    required this.step,
    required this.current,
    required this.index,
    required this.onTap,
  });

  final _SessionStep step;
  final bool current;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = LangoColors.tints[index % LangoColors.tints.length];

    return Semantics(
      button: true,
      label: '${step.title}. ${step.done ? 'Completed' : step.subtitle}',
      child: Material(
        color: Colors.transparent,
        borderRadius: LangoRadius.xlAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: LangoRadius.xlAll,
          child: Container(
            padding: const EdgeInsets.all(LangoSpace.lg),
            decoration: BoxDecoration(
              borderRadius: LangoRadius.xlAll,
              gradient: current ? tint.gradient : null,
              color: current ? null : LangoColors.surfaceMuted,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.done
                        ? LangoColors.success
                        : LangoPalette.white,
                  ),
                  child: Icon(
                    step.done ? Icons.check_rounded : step.icon,
                    size: 20,
                    color: step.done
                        ? LangoPalette.white
                        : LangoColors.primaryDeep,
                  ),
                ),
                const SizedBox(width: LangoSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: LangoType.label.copyWith(
                          color: step.done
                              ? LangoColors.foregroundMuted
                              : LangoColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.done ? 'Done' : step.subtitle,
                        style: LangoType.bodyMuted.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (!step.done)
                  const Icon(Icons.arrow_forward_rounded,
                      size: 20, color: LangoColors.primaryDeep),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
