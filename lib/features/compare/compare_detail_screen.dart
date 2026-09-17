import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/comparison.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import 'compare_screen.dart';

/// One concept, side by side (US-120, US-121).
///
/// Layout follows US-120: English at the top, then each language's version
/// underneath it. The difference and the similarity are stated separately, and
/// the equivalence badge is always present so a clean side-by-side never
/// implies the two structures are interchangeable.
class CompareDetailScreen extends ConsumerWidget {
  const CompareDetailScreen({super.key, required this.concept});

  final Concept concept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final languages =
        profile?.languages.map((l) => l.language).toList() ?? const [];

    return LangoPage(
      title: concept.kind.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.lg(),
          Text('MEANING', style: LangoType.caption),
          const Gap.xs(),
          Text(concept.english, style: LangoType.h1),
          const Gap.md(),
          Align(
            alignment: Alignment.centerLeft,
            child: EquivalenceBadge(equivalence: concept.equivalence),
          ),
          const Gap.xxl(),

          for (final language in languages) ...[
            if (concept.entryFor(language.code) case final entry?) ...[
              _LanguagePanel(language: language, entry: entry),
              const Gap.md(),
            ],
          ],

          const Gap.lg(),
          if (concept.keyDifference != null)
            _Note(
              label: 'The difference that matters',
              icon: Icons.call_split_rounded,
              color: LangoColors.warning,
              text: concept.keyDifference!,
            ),
          if (concept.similarity != null) ...[
            const Gap.md(),
            _Note(
              label: 'Where they really do line up',
              icon: Icons.merge_rounded,
              color: LangoColors.success,
              text: concept.similarity!,
            ),
          ],
          if (concept.equivalence == Equivalence.falseFriend) ...[
            const Gap.md(),
            _Note(
              label: 'Do not map one onto the other',
              icon: Icons.warning_amber_rounded,
              color: LangoColors.error,
              text: 'These look related because they share a written form. '
                  'Using one language\'s meaning in the other will be '
                  'misunderstood.',
            ),
          ],
          const Gap.xxl(),
        ],
      ),
    );
  }
}

class _LanguagePanel extends StatelessWidget {
  const _LanguagePanel({required this.language, required this.entry});

  final TargetLanguage language;
  final ConceptEntry entry;

  @override
  Widget build(BuildContext context) {
    return LangoCard.tinted(
      tint: LangoColors.tintFor(entry.language),
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: LangoSpace.xs),
              Expanded(
                child: Text(
                  language.label.toUpperCase(),
                  style: LangoType.caption,
                ),
              ),
              AudioButton(
                text: entry.exampleNative,
                language: language,
                size: AudioButtonSize.small,
              ),
            ],
          ),
          const Gap.sm(),
          Text('STRUCTURE', style: LangoType.caption),
          const SizedBox(height: 2),
          Text(
            entry.structure,
            style: LangoType.native(entry.language, size: 19),
          ),
          const Gap.md(),
          Text(
            entry.exampleNative,
            style: LangoType.native(
              entry.language,
              size: 22,
              weight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(entry.exampleTranslation, style: LangoType.bodyMuted),
          if (entry.literalGloss != null) ...[
            const SizedBox(height: LangoSpace.xxs),
            // The word-by-word gloss is where the structural difference shows
            // — it is the whole point of a side-by-side comparison.
            Text(
              entry.literalGloss!,
              style: LangoType.caption
                  .copyWith(color: LangoColors.foregroundSecondary),
            ),
          ],
          if (entry.note != null) ...[
            const Gap.sm(),
            Text(entry.note!,
                style: LangoType.bodyMuted.copyWith(fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.label,
    required this.icon,
    required this.color,
    required this.text,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: LangoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: LangoType.label),
                const SizedBox(height: 2),
                Text(text, style: LangoType.bodyMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
