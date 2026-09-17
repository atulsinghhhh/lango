import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/content.dart';
import '../../models/language.dart';

/// One character tile, shared by the writing-system browser and the per-script
/// screen rather than duplicated between them (REDESIGN.md §31).
///
/// Where it leads depends on the character, not on the language: a character
/// that carries meanings and multiple readings (a kanji) opens its detail
/// page, while an alphabetic letter goes straight to practice, because for a
/// letter there is nothing to read beyond what the tile already shows.
class CharacterTile extends StatelessWidget {
  const CharacterTile({
    super.key,
    required this.item,
    required this.language,
  });

  final CharacterItem item;
  final TargetLanguage language;

  @override
  Widget build(BuildContext context) {
    final tint = LangoColors.tintFor(item.character);
    final route =
        item.isLogographic ? '/learn/writing/character' : '/learn/writing/practice';

    return Semantics(
      button: true,
      label: item.meanings.isEmpty
          ? '${item.character}, ${item.romanization}'
          : '${item.character}, ${item.romanization}, '
              '${item.meanings.join(', ')}',
      child: Material(
        color: Colors.transparent,
        borderRadius: LangoRadius.lgAll,
        child: InkWell(
          borderRadius: LangoRadius.lgAll,
          onTap: () => context.push(route, extra: item),
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
                  style: LangoType.native(item.language, size: 30),
                ),
                const SizedBox(height: 2),
                Text(
                  // A kanji's meaning is more useful on the tile than its
                  // romanized reading; a letter has only the reading.
                  item.meanings.isNotEmpty
                      ? item.meanings.first.toUpperCase()
                      : item.romanization.toUpperCase(),
                  style: LangoType.caption.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
