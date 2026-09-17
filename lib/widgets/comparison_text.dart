import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/speech/speech_comparison.dart';

/// Renders a target sentence with each part marked as matched, missing or
/// replaced (US-071 dictation, US-081 speaking).
///
/// Shared by both screens rather than duplicated, per REDESIGN.md §31.
/// Meaning is never carried by colour alone: a missing token is struck
/// through and a replaced one shows what appeared instead, so the marking is
/// legible without colour vision.
class ComparisonText extends StatelessWidget {
  const ComparisonText({
    super.key,
    required this.comparison,
    required this.languageCode,
    this.size = 22,
  });

  final SpeechComparison comparison;
  final String languageCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Character-segmented scripts must not gain spaces between every glyph.
    final spaced = comparison.tokens.length > 1 &&
        comparison.tokens.every((t) => t.expected.length > 1);

    return Semantics(
      label: _semanticLabel(),
      excludeSemantics: true,
      child: Wrap(
        spacing: spaced ? 6 : 0,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (final token in comparison.tokens) _token(token),
        ],
      ),
    );
  }

  Widget _token(ComparedToken token) {
    final base = LangoType.native(languageCode, size: size);
    switch (token.status) {
      case TokenStatus.matched:
        return Text(token.expected, style: base);
      case TokenStatus.missing:
        return Text(
          token.expected,
          style: base.copyWith(
            color: LangoColors.foregroundMuted,
            decoration: TextDecoration.lineThrough,
            decorationColor: LangoColors.foregroundMuted,
          ),
        );
      case TokenStatus.incorrect:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(token.expected,
                style: base.copyWith(color: LangoColors.error)),
            if (token.heard != null)
              Text(
                token.heard!,
                style: LangoType.native(
                  languageCode,
                  size: size * 0.6,
                  weight: FontWeight.w400,
                  color: LangoColors.foregroundMuted,
                ),
              ),
          ],
        );
    }
  }

  String _semanticLabel() {
    final parts = <String>[];
    for (final token in comparison.tokens) {
      switch (token.status) {
        case TokenStatus.matched:
          parts.add(token.expected);
        case TokenStatus.missing:
          parts.add('${token.expected}, missing');
        case TokenStatus.incorrect:
          parts.add('${token.expected}, heard ${token.heard ?? 'something else'}');
      }
    }
    return parts.join('. ');
  }
}

/// The plain-language summary that goes under a [ComparisonText].
///
/// Lists what was missing, extra or replaced without ever calling the result a
/// pronunciation score.
class ComparisonSummary extends StatelessWidget {
  const ComparisonSummary({
    super.key,
    required this.comparison,
    required this.languageCode,
  });

  final SpeechComparison comparison;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    if (comparison.isExact) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: LangoColors.success, size: 20),
          const SizedBox(width: LangoSpace.xs),
          Text('Everything matched', style: LangoType.label),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comparison.missing.isNotEmpty)
          _line('Missing', comparison.missing),
        if (comparison.incorrect.isNotEmpty)
          _line(
            'Different',
            [
              for (final pair in comparison.incorrect)
                '${pair.expected} → ${pair.heard}',
            ],
          ),
        if (comparison.extra.isNotEmpty) _line('Extra', comparison.extra),
      ],
    );
  }

  Widget _line(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LangoSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(label.toUpperCase(), style: LangoType.caption),
          ),
          Expanded(
            child: Text(
              items.join('   '),
              style: LangoType.native(
                languageCode,
                size: 16,
                weight: FontWeight.w400,
                color: LangoColors.foregroundSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
