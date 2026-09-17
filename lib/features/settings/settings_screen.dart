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

/// Profile and preferences (REDESIGN.md §10, §31; US-006, US-150).
///
/// Every learning preference is editable here: which languages, the level and
/// goals for each, and the daily goal. Changes take effect on the next
/// recommendation, and none of them touch recorded history — US-150 is
/// explicit that learning history is not deleted unless explicitly requested,
/// so even removing a language leaves its reviews and sessions intact.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final email = ref.watch(authServiceProvider).currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: LangoBreak.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                LangoSpace.gutter,
                LangoSpace.lg,
                LangoSpace.gutter,
                LangoSpace.xxl,
              ),
              children: [
                _Identity(email: email),
                const Gap.xxl(),
                profile.when(
                  loading: () =>
                      const LangoSkeleton(height: 200, radius: LangoRadius.xl),
                  error: (e, _) => LangoError(
                    message: "We couldn't load your settings.",
                    onRetry: () => ref.invalidate(profileProvider),
                  ),
                  data: (p) => p == null
                      ? const SizedBox.shrink()
                      : _LearningSetup(profile: p),
                ),
                const Gap.xxl(),
                Text('ACCOUNT', style: LangoType.caption),
                const Gap.md(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                  onPressed: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authServiceProvider).signOut();
    ref.invalidate(profileProvider);
    if (context.mounted) context.go('/login');
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LangoColors.tints.first.gradient,
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 40,
            color: LangoColors.primaryDeep,
          ),
        ),
        if (email != null) ...[
          const Gap.md(),
          Text(
            email!,
            style: LangoType.body,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _LearningSetup extends ConsumerWidget {
  const _LearningSetup({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studied = profile.languages.map((l) => l.language).toSet();
    final available = TargetLanguage.values
        .where((l) => !studied.contains(l))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('LEARNING', style: LangoType.caption),
        const Gap.md(),

        for (final ul in profile.languages) ...[
          _LanguageCard(
            userLanguage: ul,
            // Removing the last language would leave the app with nothing to
            // teach, so the option is withheld rather than shown and refused.
            canRemove: profile.languages.length > 1,
          ),
          const Gap.md(),
        ],

        for (final language in available) ...[
          _AddLanguageRow(language: language),
          const Gap.sm(),
        ],

        const Gap.lg(),
        _DailyGoalRow(current: profile.dailyGoalMinutes),
        const Gap.md(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 16,
              color: LangoColors.foregroundMuted,
            ),
            const SizedBox(width: LangoSpace.xxs),
            Expanded(
              child: Text(
                'Changing any of this affects what we recommend next. Your '
                'reviews, sessions and history are never deleted by a change '
                'here — including removing a language.',
                style: LangoType.bodyMuted.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One studied language, with everything about it editable in place (US-150).
class _LanguageCard extends ConsumerStatefulWidget {
  const _LanguageCard({required this.userLanguage, required this.canRemove});

  final UserLanguage userLanguage;
  final bool canRemove;

  @override
  ConsumerState<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends ConsumerState<_LanguageCard> {
  bool _expanded = false;
  bool _saving = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      ref.invalidate(profileProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("We couldn't save that change.")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmRemove() async {
    final language = widget.userLanguage.language;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stop studying ${language.label}?'),
        content: const Text(
          'It disappears from your learning screens. Everything you have '
          'already studied is kept, so adding it back later picks up where '
          'you left off.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop studying'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => ref.read(profileServiceProvider).removeLanguage(language));
  }

  @override
  Widget build(BuildContext context) {
    final ul = widget.userLanguage;
    final lang = ul.language;

    return LangoCard.tinted(
      tint: LangoColors.tintFor(lang.code),
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(lang.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: LangoSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.endonym,
                      style: LangoType.native(lang.code, size: 22),
                    ),
                    const SizedBox(height: 2),
                    Text(lang.label.toUpperCase(), style: LangoType.caption),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                tooltip: _expanded ? 'Hide settings' : 'Edit level and goals',
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          if (!_expanded) ...[
            const Gap.xs(),
            Text(
              ul.goals.isEmpty
                  ? ul.level.label
                  : '${ul.level.label} · ${ul.goals.join(', ')}',
              style: LangoType.bodyMuted.copyWith(fontSize: 14),
            ),
          ],
          if (_expanded) ...[
            const Gap.lg(),
            Text('LEVEL', style: LangoType.caption),
            const Gap.xs(),
            Wrap(
              spacing: LangoSpace.xs,
              runSpacing: LangoSpace.xs,
              children: [
                for (final level in ProficiencyLevel.values)
                  ChoiceChip(
                    label: Text(level.label),
                    selected: level == ul.level,
                    onSelected: _saving
                        ? null
                        : (_) {
                            if (level == ul.level) return;
                            _run(
                              () => ref
                                  .read(profileServiceProvider)
                                  .updateLevel(lang, level),
                            );
                          },
                  ),
              ],
            ),
            const Gap.lg(),
            // US-006: goals are chosen at onboarding and changeable here.
            Text('GOALS', style: LangoType.caption),
            const Gap.xs(),
            Wrap(
              spacing: LangoSpace.xs,
              runSpacing: LangoSpace.xs,
              children: [
                for (final goal in learningGoals)
                  FilterChip(
                    label: Text(goal),
                    selected: ul.goals.contains(goal),
                    onSelected: _saving
                        ? null
                        : (selected) {
                            final goals = [...ul.goals];
                            selected ? goals.add(goal) : goals.remove(goal);
                            _run(
                              () => ref
                                  .read(profileServiceProvider)
                                  .updateGoals(lang, goals),
                            );
                          },
                  ),
              ],
            ),
            if (widget.canRemove) ...[
              const Gap.lg(),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 18,
                  ),
                  label: Text('Stop studying ${lang.label}'),
                  onPressed: _saving ? null : _confirmRemove,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AddLanguageRow extends ConsumerStatefulWidget {
  const _AddLanguageRow({required this.language});

  final TargetLanguage language;

  @override
  ConsumerState<_AddLanguageRow> createState() => _AddLanguageRowState();
}

class _AddLanguageRowState extends ConsumerState<_AddLanguageRow> {
  bool _saving = false;

  Future<void> _add() async {
    final level = await showModalBottomSheet<ProficiencyLevel>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(LangoSpace.lg),
              child: Text(
                'How much ${widget.language.label} do you already know?',
                style: LangoType.h3,
              ),
            ),
            for (final level in ProficiencyLevel.values)
              ListTile(
                title: Text(level.label),
                onTap: () => Navigator.of(context).pop(level),
              ),
            const Gap.md(),
          ],
        ),
      ),
    );
    if (level == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(profileServiceProvider)
          .addLanguage(widget.language, level);
      ref.invalidate(profileProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("We couldn't add that language.")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.md),
      onTap: _saving ? null : _add,
      semanticLabel: 'Also study ${widget.language.label}',
      child: Row(
        children: [
          const Icon(Icons.add_rounded, size: 20, color: LangoColors.primary),
          const SizedBox(width: LangoSpace.sm),
          Expanded(
            child: Text(
              'Also study ${widget.language.label}',
              style: LangoType.label.copyWith(color: LangoColors.primary),
            ),
          ),
          Text(widget.language.flag, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

class _DailyGoalRow extends ConsumerWidget {
  const _DailyGoalRow({required this.current});

  final int current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.timer_outlined,
              size: 20,
              color: LangoColors.primaryDeep,
            ),
            const SizedBox(width: LangoSpace.xs),
            Expanded(child: Text('Daily goal', style: LangoType.label)),
            Text(
              '$current min',
              style: LangoType.label.copyWith(
                color: LangoColors.foregroundMuted,
              ),
            ),
          ],
        ),
        const Gap.sm(),
        // Inline choice beats a bottom sheet for five short options.
        Wrap(
          spacing: LangoSpace.xs,
          runSpacing: LangoSpace.xs,
          children: [
            for (final minutes in dailyGoalOptions)
              ChoiceChip(
                label: Text('$minutes min'),
                selected: minutes == current,
                onSelected: (_) async {
                  if (minutes == current) return;
                  await ref
                      .read(profileServiceProvider)
                      .updateDailyGoal(minutes);
                  ref.invalidate(profileProvider);
                },
              ),
          ],
        ),
      ],
    );
  }
}
