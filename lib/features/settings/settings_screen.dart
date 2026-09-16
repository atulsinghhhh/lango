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

/// Profile (REDESIGN.md §10, §31).
///
/// Grouped into identity → learning setup → account, so settings read as a
/// short page rather than an undifferentiated list of tiles. Each language the
/// learner studies gets its own row in its own script (§12).
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
            constraints:
                const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
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
                  loading: () => const LangoSkeleton(
                      height: 200, radius: LangoRadius.xl),
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
          child: const Icon(Icons.person_rounded,
              size: 40, color: LangoColors.primaryDeep),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('LEARNING', style: LangoType.caption),
        const Gap.md(),

        // One row per language, each in its own script.
        for (final ul in profile.languages) ...[
          _LanguageRow(userLanguage: ul),
          const Gap.sm(),
        ],

        InkWell(
          onTap: () => context.push('/onboarding'),
          borderRadius: LangoRadius.mdAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: LangoSpace.sm,
              horizontal: LangoSpace.xs,
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded,
                    size: 18, color: LangoColors.primary),
                const SizedBox(width: LangoSpace.xs),
                Text('Change languages & levels',
                    style: LangoType.label
                        .copyWith(color: LangoColors.primary)),
              ],
            ),
          ),
        ),

        const Gap.lg(),
        _DailyGoalRow(current: profile.dailyGoalMinutes),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.userLanguage});

  final UserLanguage userLanguage;

  @override
  Widget build(BuildContext context) {
    final lang = userLanguage.language;

    return LangoCard.tinted(
      tint: lang == TargetLanguage.korean
          ? LangoColors.tints[0]
          : LangoColors.tints[3],
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Row(
        children: [
          Text(lang.flag, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: LangoSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.endonym,
                    style: LangoType.native(lang.code, size: 22)),
                const SizedBox(height: 2),
                Text(lang.label.toUpperCase(), style: LangoType.caption),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: LangoSpace.sm, vertical: 6),
            decoration: const BoxDecoration(
              color: LangoPalette.white,
              borderRadius: LangoRadius.pillAll,
            ),
            child: Text(userLanguage.level.label,
                style: LangoType.caption
                    .copyWith(color: LangoColors.foregroundSecondary)),
          ),
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
            const Icon(Icons.timer_outlined,
                size: 20, color: LangoColors.primaryDeep),
            const SizedBox(width: LangoSpace.xs),
            Expanded(child: Text('Daily goal', style: LangoType.label)),
            Text('$current min',
                style: LangoType.label
                    .copyWith(color: LangoColors.foregroundMuted)),
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
