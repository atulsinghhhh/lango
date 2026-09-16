import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/language_switcher.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  final Set<TargetLanguage> _languages = {};
  final Map<TargetLanguage, ProficiencyLevel> _levels = {};
  final Set<String> _goals = {};
  int _dailyGoal = 10;
  bool _busy = false;

  bool get _canContinue => switch (_step) {
        0 => _languages.isNotEmpty,
        1 => _languages.every(_levels.containsKey),
        2 => _goals.isNotEmpty,
        _ => true,
      };

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await ref.read(profileServiceProvider).completeOnboarding(
            languages: {for (final l in _languages) l: _levels[l]!},
            goals: _goals.toList(),
            dailyGoalMinutes: _dailyGoal,
          );
      ref.invalidate(profileProvider);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save your preferences. Please retry.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _languageStep(),
      _levelStep(),
      _goalsStep(),
      _dailyGoalStep(),
    ];

    return Scaffold(
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
                  child: Row(
                    children: [
                      if (_step > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Back',
                          onPressed: () => setState(() => _step--),
                        ),
                      Expanded(
                        child: Text(
                          'STEP ${_step + 1} OF ${steps.length}',
                          style: LangoType.caption,
                          textAlign:
                              _step > 0 ? TextAlign.start : TextAlign.start,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: LangoSpace.gutter),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(LangoRadius.sm),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / steps.length,
                      minHeight: 8,
                      backgroundColor: LangoColors.surfaceMuted,
                      semanticsLabel: 'Onboarding progress',
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(LangoSpace.gutter),
                    child: steps[_step],
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
                      onPressed: !_canContinue || _busy
                          ? null
                          : () {
                              if (_step < steps.length - 1) {
                                setState(() => _step++);
                              } else {
                                _finish();
                              }
                            },
                      child: Text(_step < steps.length - 1
                          ? 'Continue'
                          : 'Start learning'),
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

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: LangoSpace.lg),
        child: Text(text, style: LangoType.h2),
      );

  Widget _languageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('What do you want to learn?'),
        for (final lang in TargetLanguage.values)
          Padding(
            padding: const EdgeInsets.only(bottom: LangoSpace.sm),
            child: _SelectCard(
              selected: _languages.contains(lang),
              // Native-first: each language is offered in its own script.
              titleWidget: Row(
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: LangoSpace.sm),
                  Text(lang.endonym,
                      style: LangoType.native(lang.code, size: 22)),
                  const SizedBox(width: LangoSpace.xs),
                  Text(lang.label.toUpperCase(), style: LangoType.caption),
                ],
              ),
              onTap: () => setState(() {
                _languages.contains(lang)
                    ? _languages.remove(lang)
                    : _languages.add(lang);
              }),
            ),
          ),
        const Gap.xs(),
        Text('You can pick one or both.', style: LangoType.bodyMuted),
      ],
    );
  }

  Widget _levelStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('What is your current level?'),
        for (final lang in _languages) ...[
          Row(
            children: [
              Text(lang.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: LangoSpace.xs),
              Text(lang.endonym,
                  style: LangoType.native(lang.code, size: 18)),
            ],
          ),
          const Gap.sm(),
          Wrap(
            spacing: LangoSpace.xs,
            runSpacing: LangoSpace.xs,
            children: [
              for (final level in ProficiencyLevel.values)
                ChoiceChip(
                  label: Text(level.label),
                  selected: _levels[lang] == level,
                  onSelected: (_) => setState(() => _levels[lang] = level),
                ),
            ],
          ),
          const Gap.xl(),
        ],
      ],
    );
  }

  Widget _goalsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Why are you learning?'),
        Wrap(
          spacing: LangoSpace.xs,
          runSpacing: LangoSpace.xs,
          children: [
            for (final goal in learningGoals)
              FilterChip(
                label: Text(goal),
                selected: _goals.contains(goal),
                onSelected: (sel) => setState(() {
                  sel ? _goals.add(goal) : _goals.remove(goal);
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dailyGoalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Daily goal'),
        for (final minutes in dailyGoalOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: LangoSpace.sm),
            child: _SelectCard(
              selected: _dailyGoal == minutes,
              titleWidget: Text('$minutes minutes / day',
                  style: LangoType.label),
              onTap: () => setState(() => _dailyGoal = minutes),
            ),
          ),
      ],
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.selected,
    required this.titleWidget,
    required this.onTap,
  });

  final bool selected;
  final Widget titleWidget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: LangoRadius.xlAll,
        child: InkWell(
          borderRadius: LangoRadius.xlAll,
          onTap: onTap,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : LangoMotion.fast,
            padding: const EdgeInsets.all(LangoSpace.lg),
            decoration: BoxDecoration(
              borderRadius: LangoRadius.xlAll,
              // Selection reads as a tint change, not a border — the
              // reference has no borders.
              gradient: selected ? LangoColors.tints.first.gradient : null,
              color: selected ? null : LangoColors.surfaceMuted,
            ),
            child: Row(
              children: [
                Expanded(child: titleWidget),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: LangoColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
