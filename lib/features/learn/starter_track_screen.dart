import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/learn/starter_track.dart';
import '../../services/providers.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../writing/character_set_screen.dart';

/// The guided beginner path ("Start here").
///
/// Answers the question the Learn hub cannot: someone who has never seen
/// Hangul or Kana does not need eight equal choices, they need the first one.
/// Every step says what it is for, so the order is arguable rather than
/// arbitrary.
///
/// Later steps are dimmed, not removed, and the Learn hub still opens all of
/// them directly. A learner who wants to jump ahead is not blocked — the
/// track is advice, not a gate.
class StarterTrackScreen extends ConsumerWidget {
  const StarterTrackScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(starterTrackProvider(language.code));

    return LangoPage(
      title: 'Start here',
      child: LangoAsync<StarterTrackPlan?>(
        value: (
          data: plan.value,
          error: plan.error,
          isLoading: plan.isLoading,
        ),
        onRetry: () => ref.invalidate(starterTrackProvider(language.code)),
        errorMessage:
            "We couldn't work out where you are. Check your connection.",
        data: (value) {
          if (value == null) {
            return const LangoEmpty(
              icon: Icons.explore_outlined,
              title: 'No guided path for this language',
              message: 'Pick any skill from Learn and start wherever you like.',
            );
          }
          return _Track(plan: value, language: language);
        },
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.plan, required this.language});

  final StarterTrackPlan plan;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Intro(plan: plan, language: language),
        const Gap.xl(),
        for (var i = 0; i < plan.steps.length; i++) ...[
          _StepCard(
            step: plan.steps[i],
            number: i + 1,
            language: language,
          ),
          if (i != plan.steps.length - 1) const Gap.card(),
        ],
        const Gap.xl(),
        Text(
          'You can open any of these from Learn at any time. The order is a '
          'suggestion, not a lock.',
          style: LangoType.caption
              .copyWith(color: LangoColors.foregroundMuted),
        ),
        const Gap.xxl(),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.plan, required this.language});

  final StarterTrackPlan plan;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    final done = plan.doneCount;
    final total = plan.steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plan.isComplete
              ? "You've been through all of it"
              : 'Your path through ${language.label}',
          style: LangoType.h2,
        ),
        const Gap.xs(),
        Text(
          plan.isComplete
              ? 'Every mode has been tried at least once. From here, Home '
                  'picks what to do next based on what you are getting wrong.'
              : 'Each step builds on the one before it. Start at the top — the '
                  'first few sittings are about the alphabet, not about words.',
          style: LangoType.bodyMuted,
        ),
        const Gap.md(),
        Semantics(
          label: '$done of $total steps done',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(LangoRadius.sm),
                child: LinearProgressIndicator(
                  value: plan.fraction,
                  minHeight: 10,
                  backgroundColor: LangoColors.surfaceMuted,
                ),
              ),
              const Gap.xs(),
              Text('$done of $total done',
                  style: LangoType.caption
                      .copyWith(color: LangoColors.foregroundMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.number,
    required this.language,
  });

  final StarterStep step;
  final int number;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    // Only the current step is tinted. Tinting every card would make the path
    // read as eight equal options again, which is the problem the track
    // exists to solve.
    final tint = step.isCurrent
        ? LangoColors.tints[(number - 1) % LangoColors.tints.length]
        : null;

    final onTap = step.isLocked ? null : () => _open(context);

    return Opacity(
      // Locked steps stay legible — a learner should be able to read what is
      // coming — but clearly recede.
      opacity: step.isLocked ? 0.55 : 1,
      child: LangoCard(
        tint: tint,
        onTap: onTap,
        semanticLabel: _semanticLabel(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Marker(step: step, number: number),
                const SizedBox(width: LangoSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(step.title, style: LangoType.h3),
                      const SizedBox(height: 2),
                      Text(
                        step.purpose,
                        style: LangoType.body.copyWith(
                          color: LangoColors.foregroundSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!step.isLocked)
                  Icon(
                    step.isDone
                        ? Icons.refresh_rounded
                        : Icons.arrow_forward_rounded,
                    color: LangoColors.primaryDeep,
                    size: 22,
                  ),
              ],
            ),
            if (step.isCurrent && step.progress != null) ...[
              const Gap.md(),
              ClipRRect(
                borderRadius: BorderRadius.circular(LangoRadius.sm),
                child: LinearProgressIndicator(
                  value: step.progress,
                  minHeight: 8,
                  backgroundColor: LangoPalette.white,
                ),
              ),
            ],
            if (step.nextHint != null) ...[
              const Gap.xs(),
              Text(
                step.nextHint!,
                style: LangoType.caption
                    .copyWith(color: LangoColors.foregroundSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _semanticLabel() {
    final status = switch (step.state) {
      StarterStepState.done => 'done',
      StarterStepState.current => 'do this next',
      StarterStepState.locked => 'comes later',
    };
    return 'Step $number, $status. ${step.title}. ${step.purpose}';
  }

  void _open(BuildContext context) {
    // A script step goes straight into its own set rather than the list of
    // scripts: the whole point of the track is to remove the choice.
    final script = step.script;
    if (script != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CharacterSetScreen(
            language: language,
            script: script,
            title: scriptLabel(script),
          ),
        ),
      );
      return;
    }
    context.push('${step.route}?lang=${language.code}');
  }
}

/// The step number, or a tick once it is done.
class _Marker extends StatelessWidget {
  const _Marker({required this.step, required this.number});

  final StarterStep step;
  final int number;

  @override
  Widget build(BuildContext context) {
    final done = step.isDone;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: done ? LangoColors.primaryDeep : LangoPalette.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded,
              color: LangoColors.primaryForeground, size: 22)
          : Text('$number',
              style: LangoType.label
                  .copyWith(color: LangoColors.primaryDeep)),
    );
  }
}
