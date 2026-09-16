import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
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

    return LangoPage(
      title: 'Learn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (languages.length > 1) ...[
            LanguageSwitcher(languages: languages),
            const Gap.xl(),
          ],
          Text(
            'What would you like to practise?',
            style: LangoType.h2,
          ),
          const Gap.xl(),
          for (var i = 0; i < skills.length; i++) ...[
            _SkillCard(skill: skills[i], language: lang, index: i),
            if (i != skills.length - 1) const Gap.card(),
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
      _Skill('Speaking', 'Say it out loud', Icons.mic_rounded, '/speaking'),
    ];
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
