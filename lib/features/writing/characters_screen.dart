import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';
import 'character_set_screen.dart';
import 'character_tile.dart';

final charactersProvider = FutureProvider.autoDispose
    .family<List<CharacterItem>, String>((ref, language) async {
  return ref.watch(contentServiceProvider).characters(language, limit: 500);
});

/// Script codes, as stored, to the heading a learner recognises. Unknown codes
/// fall through to the raw code, so a new script still renders.
const _scriptLabels = {
  'hangul_consonant': 'Consonants',
  'hangul_vowel': 'Vowels',
  'hiragana': 'Hiragana',
  'katakana': 'Katakana',
  'kanji': 'Kanji',
};

/// Above this many characters a script gets a preview plus its own screen
/// instead of a grid that buries everything under it (US-061: a kanji set is
/// far larger than an alphabet).
const _previewLimit = 24;

/// Writing system browser (REDESIGN.md §16, §17).
///
/// The character is visually prioritised — it fills its tile in the native
/// face, with a small tracked caption beneath. Scripts are grouped, and each
/// group is read from the data rather than assumed per language.
class CharactersScreen extends ConsumerWidget {
  const CharactersScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(charactersProvider(language.code));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Writing'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: LangoSpace.md),
            child: Center(
              child: Text(language.flag, style: const TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
            child: chars.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(LangoSpace.gutter),
                child: LangoSkeletonList(count: 3),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(LangoSpace.gutter),
                child: LangoError(
                  message: "We couldn't load the characters. "
                      'Check your connection.',
                  onRetry: () =>
                      ref.invalidate(charactersProvider(language.code)),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(LangoSpace.gutter),
                    child: LangoEmpty(
                      icon: Icons.draw_outlined,
                      title: 'No characters yet',
                      message:
                          'The writing system for this language has not been '
                          'added.',
                    ),
                  );
                }

                final byScript = <String, List<CharacterItem>>{};
                for (final c in items) {
                  byScript.putIfAbsent(c.script, () => []).add(c);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    LangoSpace.gutter,
                    LangoSpace.md,
                    LangoSpace.gutter,
                    LangoSpace.xxl,
                  ),
                  children: [
                    for (final entry in byScript.entries) ...[
                      _ScriptSection(
                        script: entry.key,
                        title: _scriptLabels[entry.key] ?? entry.key,
                        characters: entry.value,
                        language: language,
                      ),
                      const Gap.xxl(),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ScriptSection extends StatelessWidget {
  const _ScriptSection({
    required this.script,
    required this.title,
    required this.characters,
    required this.language,
  });

  final String script;
  final String title;
  final List<CharacterItem> characters;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    final truncated = characters.length > _previewLimit;
    final shown =
        truncated ? characters.take(_previewLimit).toList() : characters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(title.toUpperCase(), style: LangoType.caption)),
            if (truncated)
              Text('${characters.length}', style: LangoType.caption),
          ],
        ),
        const Gap.md(),
        LayoutBuilder(
          builder: (context, c) {
            final columns = (c.maxWidth / 92).floor().clamp(3, 8);
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: LangoSpace.sm,
              crossAxisSpacing: LangoSpace.sm,
              children: [
                for (final item in shown)
                  CharacterTile(item: item, language: language),
              ],
            );
          },
        ),
        if (truncated) ...[
          const Gap.md(),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CharacterSetScreen(
                  language: language,
                  script: script,
                  title: title,
                ),
              ),
            ),
            child: Text('See all ${characters.length} $title'),
          ),
        ],
      ],
    );
  }
}
