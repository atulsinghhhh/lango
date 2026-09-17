import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';
import '../../services/providers.dart';
import '../../widgets/lango_states.dart';
import 'character_tile.dart';

/// Every character in one script, with its curriculum levels as filters.
///
/// Split out from [CharactersScreen] because a logographic set is far larger
/// than an alphabet: kanji arrive by JLPT band and need filtering, where
/// Hangul and Kana fit on one screen (US-061).
final characterSetProvider = FutureProvider.autoDispose
    .family<List<CharacterItem>, ({String language, String script, String? level})>(
        (ref, key) async {
  return ref.watch(contentServiceProvider).characters(
        key.language,
        script: key.script,
        level: key.level,
        limit: 500,
      );
});

final characterLevelsProvider = FutureProvider.autoDispose
    .family<List<String>, ({String language, String script})>((ref, key) async {
  return ref
      .watch(contentServiceProvider)
      .characterLevels(key.language, key.script);
});

class CharacterSetScreen extends ConsumerStatefulWidget {
  const CharacterSetScreen({
    super.key,
    required this.language,
    required this.script,
    required this.title,
  });

  final TargetLanguage language;
  final String script;
  final String title;

  @override
  ConsumerState<CharacterSetScreen> createState() =>
      _CharacterSetScreenState();
}

class _CharacterSetScreenState extends ConsumerState<CharacterSetScreen> {
  String? _level;

  @override
  Widget build(BuildContext context) {
    final levels = ref.watch(characterLevelsProvider(
        (language: widget.language.code, script: widget.script)));
    final key = (
      language: widget.language.code,
      script: widget.script,
      level: _level,
    );
    final characters = ref.watch(characterSetProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: LangoSpace.md),
            child: Center(
              child: Text(widget.language.flag,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
            child: Column(
              children: [
                // Filters only exist where the data has levels; an alphabet
                // has none and gets no empty filter row.
                levels.maybeWhen(
                  data: (values) => values.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(
                            LangoSpace.gutter,
                            LangoSpace.sm,
                            LangoSpace.gutter,
                            0,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('All'),
                                  selected: _level == null,
                                  onSelected: (_) =>
                                      setState(() => _level = null),
                                ),
                                for (final level in values) ...[
                                  const SizedBox(width: LangoSpace.xs),
                                  ChoiceChip(
                                    label: Text(level),
                                    selected: _level == level,
                                    onSelected: (_) =>
                                        setState(() => _level = level),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
                Expanded(
                  child: characters.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(LangoSpace.gutter),
                      child: LangoSkeletonList(count: 3),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.all(LangoSpace.gutter),
                      child: LangoError(
                        message: "We couldn't load these characters. "
                            'Check your connection.',
                        onRetry: () =>
                            ref.invalidate(characterSetProvider(key)),
                      ),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(LangoSpace.gutter),
                          child: LangoEmpty(
                            icon: Icons.draw_outlined,
                            title: 'Nothing at this level yet',
                            message: 'Try another level, or All.',
                          ),
                        );
                      }
                      return LayoutBuilder(
                        builder: (context, c) {
                          final columns =
                              (c.maxWidth / 92).floor().clamp(3, 8);
                          return GridView.count(
                            crossAxisCount: columns,
                            padding: const EdgeInsets.fromLTRB(
                              LangoSpace.gutter,
                              LangoSpace.md,
                              LangoSpace.gutter,
                              LangoSpace.xxl,
                            ),
                            mainAxisSpacing: LangoSpace.sm,
                            crossAxisSpacing: LangoSpace.sm,
                            children: [
                              for (final item in items)
                                CharacterTile(
                                    item: item, language: widget.language),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
