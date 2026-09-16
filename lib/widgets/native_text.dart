import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Native-first text pairing (REDESIGN.md §7, §13).
///
/// The reference's defining move: the Korean/Japanese word is the largest
/// element on the surface, and the English gloss sits beneath it in small
/// uppercase with generous tracking. The native text is never styled as
/// secondary metadata.
class NativeWord extends StatelessWidget {
  const NativeWord({
    super.key,
    required this.word,
    required this.languageCode,
    this.gloss,
    this.romanization,
    this.size = 22,
    this.align = CrossAxisAlignment.start,
    this.color = LangoColors.foreground,
  });

  /// Hero treatment for one-task-at-a-time study screens.
  const NativeWord.hero({
    super.key,
    required this.word,
    required this.languageCode,
    this.gloss,
    this.romanization,
    this.color = LangoColors.foreground,
  })  : size = 64,
        align = CrossAxisAlignment.center;

  final String word;
  final String languageCode;

  /// English meaning — rendered uppercase and tracked, as in the reference.
  final String? gloss;

  /// Romanisation / reading, shown between the word and the gloss.
  final String? romanization;

  final double size;
  final CrossAxisAlignment align;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textAlign =
        align == CrossAxisAlignment.center ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          word,
          textAlign: textAlign,
          style: LangoType.native(languageCode, size: size, color: color),
        ),
        if (romanization != null) ...[
          const SizedBox(height: LangoSpace.xxs),
          Text(
            romanization!,
            textAlign: textAlign,
            style: LangoType.body.copyWith(
              color: LangoColors.foregroundSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (gloss != null) ...[
          SizedBox(height: romanization == null ? LangoSpace.xxs : 2),
          Text(
            gloss!.toUpperCase(),
            textAlign: textAlign,
            style: LangoType.caption,
          ),
        ],
      ],
    );
  }
}

/// A sentence of native content with its translation beneath — used for
/// examples in vocabulary and grammar (REDESIGN.md §15).
class NativeSentence extends StatelessWidget {
  const NativeSentence({
    super.key,
    required this.sentence,
    required this.languageCode,
    this.translation,
    this.size = 20,
  });

  final String sentence;
  final String languageCode;
  final String? translation;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sentence,
          style: LangoType.native(
            languageCode,
            size: size,
            weight: FontWeight.w400,
            height: 1.45,
          ),
        ),
        if (translation != null) ...[
          const SizedBox(height: LangoSpace.xxs),
          Text(translation!, style: LangoType.bodyMuted),
        ],
      ],
    );
  }
}
