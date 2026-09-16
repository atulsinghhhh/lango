import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/language.dart';
import 'audio_button.dart';
import 'lango_page.dart';
import 'native_text.dart';

/// The shared study surface used by flashcards and review (REDESIGN.md §13,
/// §14, §24).
///
/// One task at a time: the native word fills the card, audio sits with it, and
/// nothing else competes until the answer is revealed. Flashcards and review
/// previously duplicated near-identical card code — this is the single
/// implementation (§31, "do not duplicate nearly identical components").
class StudyCard extends StatelessWidget {
  const StudyCard({
    super.key,
    required this.front,
    required this.language,
    required this.revealed,
    required this.onReveal,
    this.romanization,
    this.back,
    this.subtitle,
    this.exampleNative,
    this.exampleTranslation,
    this.speakText,
    this.tint,
  });

  final String front;
  final TargetLanguage language;
  final bool revealed;
  final VoidCallback onReveal;

  final String? romanization;
  final String? back;
  final String? subtitle;
  final String? exampleNative;
  final String? exampleTranslation;
  final String? speakText;
  final LangoTint? tint;

  @override
  Widget build(BuildContext context) {
    final t = tint ?? LangoColors.tintFor(front);

    // Long words must not overflow the hero size on a 320pt screen.
    final heroSize = front.characters.length > 6 ? 44.0 : 64.0;

    return Semantics(
      label: revealed ? '$front. $back' : '$front. Tap to reveal the answer.',
      button: !revealed,
      child: Material(
        color: Colors.transparent,
        borderRadius: LangoRadius.xlAll,
        child: InkWell(
          onTap: revealed ? null : onReveal,
          borderRadius: LangoRadius.xlAll,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: LangoRadius.xlAll,
              gradient: t.gradient,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: LangoSpace.xl,
              vertical: LangoSpace.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    front,
                    textAlign: TextAlign.center,
                    style: LangoType.native(
                      language.code,
                      size: heroSize,
                      height: 1.15,
                    ),
                  ),
                ),
                if (speakText != null) ...[
                  const Gap.md(),
                  AudioButton(text: speakText!, language: language),
                ],
                if (!revealed) ...[
                  const Gap.lg(),
                  Text('Tap to reveal', style: LangoType.caption),
                ] else ...[
                  const Gap.lg(),
                  const Divider(color: LangoColors.border),
                  const Gap.lg(),
                  if (romanization != null) ...[
                    Text(
                      romanization!,
                      textAlign: TextAlign.center,
                      style: LangoType.label.copyWith(
                        color: LangoColors.foregroundSecondary,
                      ),
                    ),
                    const Gap.xs(),
                  ],
                  if (back != null)
                    Text(
                      back!,
                      textAlign: TextAlign.center,
                      style: LangoType.h2,
                    ),
                  if (subtitle != null) ...[
                    const Gap.xs(),
                    Text(subtitle!,
                        textAlign: TextAlign.center, style: LangoType.caption),
                  ],
                  if (exampleNative != null) ...[
                    const Gap.md(),
                    NativeSentence(
                      sentence: exampleNative!,
                      languageCode: language.code,
                      translation: exampleTranslation,
                      size: 18,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Session progress header: a bar plus "n / total" (REDESIGN.md §23, §24).
class StudyProgress extends StatelessWidget {
  const StudyProgress({super.key, required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(LangoRadius.sm),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : (index + 1) / total,
            minHeight: 8,
            backgroundColor: LangoColors.surfaceMuted,
            semanticsLabel: 'Session progress',
            semanticsValue: '${index + 1} of $total',
          ),
        ),
        const Gap.xs(),
        Text('${index + 1} / $total', style: LangoType.caption),
      ],
    );
  }
}
