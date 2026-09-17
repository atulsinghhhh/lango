import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
import '../../services/learn/starter_track.dart';
import '../../services/providers.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/language_switcher.dart';

/// Learn hub (REDESIGN.md §10, §13).
///
/// One place that answers "what can I study?", scoped to the active language.
/// Each skill is a tinted card in the reference's style; the tint is stable per
/// skill so the same area always reads the same colour across the product.
class LearnHubScreen extends ConsumerWidget {
  const LearnHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final lang = ref.watch(effectiveLanguageProvider);
    final languages = profile?.languages ?? const [];

    if (lang == null) {
      return const LangoPage(
        title: 'Learn',
        child: LangoEmpty(
          icon: Icons.school_outlined,
          title: 'No language selected yet',
          message: 'Finish onboarding to choose Korean or Japanese.',
        ),
      );
    }

    final skills = _skillsFor(lang);
    final track = ref.watch(starterTrackProvider(lang.code)).value;

    return LangoPage(
      title: 'Learn',
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search',
          onPressed: () => context.push('/learn/search?lang=${lang.code}'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (languages.length > 1) ...[
            LanguageSwitcher(languages: languages),
            const Gap.xl(),
          ],
          // Offered before the skill grid, because a complete beginner
          // choosing from eight equal cards is the problem this solves. It
          // disappears once every step is done. While it loads, nothing is
          // drawn rather than a skeleton: the hub's own content is already on
          // screen, and a placeholder that pushes it down reads as a fault.
          if (track != null && !track.isComplete) ...[
            _StartHereCard(plan: track, language: lang),
            const Gap.card(),
          ],
          Text(
            track != null && !track.isComplete
                ? 'Or pick something yourself'
                : 'What would you like to practise?',
            style: LangoType.h2,
          ),
          const Gap.xl(),
          for (var i = 0; i < skills.length; i++) ...[
            _SkillCard(skill: skills[i], language: lang, index: i),
            if (i != skills.length - 1) const Gap.card(),
          ],

          // Comparison only makes sense with a second language to compare
          // against, so it appears when there is one and not before (US-120).
          if (languages.length > 1) ...[
            const Gap.card(),
            _SkillCard(
              skill: const _Skill(
                'Compare languages',
                'The same idea, side by side',
                Icons.compare_arrows_rounded,
                '/learn/compare',
              ),
              language: lang,
              index: skills.length,
            ),
          ],
          const Gap.xl(),
        ],
      ),
    );
  }

  List<_Skill> _skillsFor(TargetLanguage lang) {
    final writingLabel =
        lang == TargetLanguage.korean ? 'Hangul' : 'Hiragana & Katakana';
    return [
      _Skill('Vocabulary', 'Words, readings and examples',
          Icons.style_rounded, '/learn/vocabulary'),
      _Skill('Grammar', 'Patterns explained with real sentences',
          Icons.menu_book_rounded, '/learn/grammar'),
      _Skill(writingLabel, 'Learn and practise the writing system',
          Icons.draw_rounded, '/learn/writing'),
      _Skill('Listening', 'Train your ear on spoken words',
          Icons.headphones_rounded, '/learn/listening'),
      _Skill('Dictation', 'Type what you hear', Icons.keyboard_rounded,
          '/learn/dictation'),
      _Skill('Speaking', 'Say it out loud', Icons.mic_rounded, '/speaking'),
    ];
  }
}

/// The entry point to the guided path (see [StarterTrackScreen]).
///
/// Names the next step rather than saying "start here", so the card answers
/// the question instead of promising an answer one tap away.
class _StartHereCard extends StatelessWidget {
  const _StartHereCard({required this.plan, required this.language});

  final StarterTrackPlan plan;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    final step = plan.current;
    final total = plan.steps.length;

    return LangoCard.tinted(
      tint: LangoColors.tints.first,
      semanticLabel: 'Start here. Step ${plan.doneCount + 1} of $total: '
          '${step?.title ?? ''}',
      onTap: () => context.push('/learn/start?lang=${language.code}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEW TO ${language.label.toUpperCase()}?',
              style: LangoType.caption.copyWith(
                color: LangoColors.primaryDeep,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              )),
          const Gap.xs(),
          Text(step?.title ?? 'Start here', style: LangoType.h2),
          const Gap.xxs(),
          Text(
            'Step ${plan.doneCount + 1} of $total on the guided path.',
            style: LangoType.body.copyWith(
              color: LangoColors.foregroundSecondary,
              fontSize: 14,
            ),
          ),
          const Gap.md(),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(LangoRadius.sm),
                  child: LinearProgressIndicator(
                    value: plan.fraction,
                    minHeight: 8,
                    backgroundColor: LangoPalette.white,
                  ),
                ),
              ),
              const SizedBox(width: LangoSpace.sm),
              const Icon(Icons.arrow_forward_rounded,
                  color: LangoColors.primaryDeep, size: 22),
            ],
          ),
        ],
      ),
    );
  }
}

class _Skill {
  const _Skill(this.title, this.subtitle, this.icon, this.route);
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.skill,
    required this.language,
    required this.index,
  });

  final _Skill skill;
  final TargetLanguage language;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tint = LangoColors.tints[index % LangoColors.tints.length];

    return LangoCard.tinted(
      tint: tint,
      semanticLabel: '${skill.title}. ${skill.subtitle}',
      onTap: () => context.push('${skill.route}?lang=${language.code}'),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: LangoPalette.white,
              shape: BoxShape.circle,
            ),
            child: Icon(skill.icon, color: LangoColors.primaryDeep, size: 26),
          ),
          const SizedBox(width: LangoSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(skill.title, style: LangoType.h3),
                const SizedBox(height: 2),
                Text(
                  skill.subtitle,
                  style: LangoType.body.copyWith(
                    color: LangoColors.foregroundSecondary,
                    fontSize: 14,
                  ),
                ),
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
