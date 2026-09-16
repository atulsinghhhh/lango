import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/lango_page.dart';
import '../../widgets/lango_states.dart';

final charactersProvider = FutureProvider.autoDispose
    .family<List<CharacterItem>, String>((ref, language) async {
  return ref.watch(contentServiceProvider).characters(language);
});

const _scriptLabels = {
  'hangul_consonant': 'Consonants',
  'hangul_vowel': 'Vowels',
  'hiragana': 'Hiragana',
  'katakana': 'Katakana',
};

/// Writing system browser (REDESIGN.md §16, §17).
///
/// The character is visually prioritised — it fills its tile in the native
/// face, with the romanisation as a small tracked caption beneath. Scripts are
/// grouped (consonants/vowels for Hangul; hiragana/katakana for Japanese).
class CharactersScreen extends ConsumerWidget {
  const CharactersScreen({super.key, required this.language});

  final TargetLanguage language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(charactersProvider(language.code));
    final title = language == TargetLanguage.korean ? 'Hangul' : 'Kana';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
                      Text(
                        (_scriptLabels[entry.key] ?? entry.key).toUpperCase(),
                        style: LangoType.caption,
                      ),
                      const Gap.md(),
                      LayoutBuilder(
                        builder: (context, c) {
                          final columns =
                              (c.maxWidth / 92).floor().clamp(3, 8);
                          return GridView.count(
                            crossAxisCount: columns,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: LangoSpace.sm,
                            crossAxisSpacing: LangoSpace.sm,
                            children: [
                              for (final ch in entry.value)
                                _CharacterTile(
                                  item: ch,
                                  language: language,
                                ),
                            ],
                          );
                        },
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

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({required this.item, required this.language});

  final CharacterItem item;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    final tint = LangoColors.tintFor(item.character);

    return Semantics(
      button: true,
      label: '${item.character}, ${item.romanization}',
      child: Material(
        color: Colors.transparent,
        borderRadius: LangoRadius.lgAll,
        child: InkWell(
          borderRadius: LangoRadius.lgAll,
          onTap: () => context.push('/learn/writing/practice', extra: item),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: LangoRadius.lgAll,
              gradient: tint.gradient,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.character,
                  style: LangoType.native(language.code, size: 30),
                ),
                const SizedBox(height: 2),
                Text(item.romanization.toUpperCase(),
                    style: LangoType.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
