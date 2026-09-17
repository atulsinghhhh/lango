import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/audio_button.dart';
import '../../widgets/lango_card.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import '../../widgets/native_text.dart';

final characterVocabularyProvider = FutureProvider.autoDispose
    .family<List<VocabItem>, String>((ref, characterId) async {
  return ref.watch(contentServiceProvider).characterVocabulary(characterId);
});

/// One logographic character in full (US-061).
///
/// Shows what the data actually holds: meanings, each reading group, the
/// curriculum level, and real vocabulary that uses it. Stroke order is not
/// shown, and stroke count appears only when the record has a verified one —
/// guessing either would be inventing information (CLAUDE.md).
class CharacterDetailScreen extends ConsumerWidget {
  const CharacterDetailScreen({super.key, required this.character});

  final CharacterItem character;

  /// Reading-group codes, as stored, to the label a learner recognises.
  /// Unknown codes fall back to the code itself so new groups still render.
  static const _readingLabels = <String, String>{
    'on': 'On reading (音読み)',
    'kun': 'Kun reading (訓読み)',
    'nanori': 'Name reading (名乗り)',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = TargetLanguage.fromCode(character.language);
    final vocabulary = ref.watch(characterVocabularyProvider(character.id));

    return LangoPage(
      title: character.character,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap.lg(),
          Center(
            child: Column(
              children: [
                Text(
                  character.character,
                  style: LangoType.native(character.language, size: 96),
                ),
                if (character.meanings.isNotEmpty) ...[
                  const Gap.sm(),
                  Text(
                    character.meanings.join(' · ').toUpperCase(),
                    style: LangoType.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
                const Gap.md(),
                AudioButton(
                  text: character.character,
                  language: language,
                  size: AudioButtonSize.medium,
                ),
              ],
            ),
          ),
          const Gap.xxl(),

          if (character.readings.isNotEmpty) ...[
            Text('READINGS', style: LangoType.caption),
            const Gap.md(),
            for (final entry in character.readings.entries)
              if (entry.value.isNotEmpty) ...[
                _ReadingRow(
                  label: _readingLabels[entry.key] ?? entry.key,
                  readings: entry.value,
                  languageCode: character.language,
                ),
                const Gap.sm(),
              ],
            const Gap.lg(),
          ],

          _Facts(character: character),
          const Gap.xxl(),

          Text('WORDS THAT USE IT', style: LangoType.caption),
          const Gap.md(),
          vocabulary.when(
            loading: () => const LangoSkeleton(height: 90,
                radius: LangoRadius.xl),
            error: (_, _) => LangoError(
              message: "We couldn't load example words.",
              onRetry: () =>
                  ref.invalidate(characterVocabularyProvider(character.id)),
            ),
            data: (words) {
              if (words.isEmpty) {
                return const LangoEmpty(
                  icon: Icons.style_outlined,
                  title: 'No example words yet',
                  message: 'This character has not been linked to vocabulary '
                      'in the library.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final word in words) ...[
                    _WordRow(item: word, language: language),
                    const Gap.sm(),
                  ],
                ],
              );
            },
          ),
          const Gap.xxl(),

          FilledButton.icon(
            icon: const Icon(Icons.draw_rounded),
            label: const Text('Practise this character'),
            onPressed: () =>
                context.push('/learn/writing/practice', extra: character),
          ),
          const Gap.xl(),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({
    required this.label,
    required this.readings,
    required this.languageCode,
  });

  final String label;
  final List<String> readings;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: LangoType.caption),
          const SizedBox(height: LangoSpace.xxs),
          Text(
            readings.join('  ·  '),
            style: LangoType.native(languageCode, size: 22),
          ),
        ],
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.character});

  final CharacterItem character;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[
      if (character.levelLabel != null)
        (label: 'Level', value: character.levelLabel!),
      (label: 'Romanization', value: character.romanization),
      if (character.strokeCount != null)
        (label: 'Strokes', value: '${character.strokeCount}'),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return LangoCard(
      padding: const EdgeInsets.all(LangoSpace.lg),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              children: [
                Expanded(
                    child: Text(rows[i].label, style: LangoType.bodyMuted)),
                Text(rows[i].value, style: LangoType.label),
              ],
            ),
            if (i != rows.length - 1) const Gap.sm(),
          ],
          if (character.strokeCount == null) ...[
            const Gap.sm(),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: LangoColors.foregroundMuted),
                const SizedBox(width: LangoSpace.xxs),
                Expanded(
                  child: Text(
                    'Stroke count and stroke order are not shown for this '
                    'character — we only show counts we have verified.',
                    style: LangoType.bodyMuted.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.item, required this.language});

  final VocabItem item;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    return LangoCard.tinted(
      tint: LangoColors.tintFor(item.id),
      padding: const EdgeInsets.all(LangoSpace.md),
      child: Row(
        children: [
          Expanded(
            child: NativeWord(
              word: item.word,
              languageCode: item.language,
              romanization: item.romanization,
              gloss: item.translation,
              size: 22,
            ),
          ),
          AudioButton(
            text: item.word,
            language: language,
            size: AudioButtonSize.small,
          ),
        ],
      ),
    );
  }
}
