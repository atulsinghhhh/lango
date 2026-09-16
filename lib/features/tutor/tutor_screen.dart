import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/language_switcher.dart';
import '../../widgets/native_text.dart';

/// AI Tutor (REDESIGN.md §20, §21).
///
/// The conversation environment is designed and navigable, but **no model is
/// wired up yet** — there is no LLM backend in this project, and an API key
/// cannot ship inside a Flutter client. Rather than fake a conversation, this
/// screen shows the scenarios the learner will be able to practise and states
/// plainly that it is not live. Nothing here invents learner data.
class TutorScreen extends ConsumerWidget {
  const TutorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final lang = ref.watch(effectiveLanguageProvider) ?? TargetLanguage.korean;
    final languages = profile?.languages ?? const [];

    final scenarios = _scenariosFor(lang);

    return LangoPage(
      title: 'Tutor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (languages.length > 1) ...[
            LanguageSwitcher(languages: languages),
            const Gap.xl(),
          ],
          Text('Practise a real conversation', style: LangoType.h2),
          const Gap.xs(),
          Text(
            'Pick a situation and talk your way through it in '
            '${lang.endonym}.',
            style: LangoType.bodyMuted,
          ),
          const Gap.xl(),

          // Honest status — no fake chat, no invented progress.
          LangoCard(
            padding: const EdgeInsets.all(LangoSpace.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.construction_rounded,
                    color: LangoColors.warning, size: 22),
                const SizedBox(width: LangoSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Not available yet', style: LangoType.label),
                      const SizedBox(height: 2),
                      Text(
                        'Conversations need a language model connected to the '
                        'app. The scenarios below are what Tutor will open '
                        'with once it is.',
                        style: LangoType.bodyMuted.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap.xl(),

          Text('Scenarios', style: LangoType.h3),
          const Gap.md(),
          for (var i = 0; i < scenarios.length; i++) ...[
            _ScenarioCard(scenario: scenarios[i], index: i, language: lang),
            if (i != scenarios.length - 1) const Gap.md(),
          ],
          const Gap.xl(),
        ],
      ),
    );
  }

  List<_Scenario> _scenariosFor(TargetLanguage lang) =>
      switch (lang) {
        TargetLanguage.korean => const [
            _Scenario('☕', 'Café', '무엇을 드릴까요?', 'What can I get you?'),
            _Scenario('🚉', 'Directions', '역이 어디예요?',
                'Where is the station?'),
            _Scenario('🍜', 'Restaurant', '주문하시겠어요?',
                'Are you ready to order?'),
            _Scenario('🙋', 'Introductions', '이름이 뭐예요?',
                "What's your name?"),
          ],
        TargetLanguage.japanese => const [
            _Scenario('☕', 'Café', 'ご注文はお決まりですか。',
                'Have you decided on your order?'),
            _Scenario('🚉', 'Directions', '駅はどこですか。',
                'Where is the station?'),
            _Scenario('🍜', 'Restaurant', '何名様ですか。',
                'How many people?'),
            _Scenario('🙋', 'Introductions', 'お名前は何ですか。',
                'What is your name?'),
          ],
      };
}

class _Scenario {
  const _Scenario(this.emoji, this.title, this.line, this.translation);
  final String emoji;
  final String title;
  final String line;
  final String translation;
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.index,
    required this.language,
  });

  final _Scenario scenario;
  final int index;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    final tint = LangoColors.tints[index % LangoColors.tints.length];

    return Opacity(
      // Visibly inactive — the learner should not tap expecting a conversation.
      opacity: 0.85,
      child: LangoCard.tinted(
        tint: tint,
        padding: const EdgeInsets.all(LangoSpace.lg),
        semanticLabel:
            '${scenario.title} scenario. Not available yet.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(scenario.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: LangoSpace.xs),
                Text(scenario.title, style: LangoType.h3),
              ],
            ),
            const SizedBox(height: LangoSpace.sm),
            NativeSentence(
              sentence: scenario.line,
              languageCode: language.code,
              translation: scenario.translation,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
