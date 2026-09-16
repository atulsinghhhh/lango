import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/srs/srs_engine.dart';

/// SM-2 rating control (REDESIGN.md §24).
///
/// Four options must stay legible on a 320pt screen. The previous single-row
/// layout clipped its own labels ("Agai n", "Goo d") on a 1080px device, so
/// this falls back to a 2×2 grid whenever four across would be too tight.
///
/// Rating colours come from the semantic status tokens rather than raw
/// `Colors.red`/`Colors.green`, so they stay inside the pastel system.
class ReviewRatingBar extends StatelessWidget {
  const ReviewRatingBar({
    super.key,
    required this.onRate,
    this.enabled = true,
  });

  final ValueChanged<ReviewRating> onRate;
  final bool enabled;

  static const _options = <({String label, ReviewRating rating, Color color})>[
    (label: 'Again', rating: ReviewRating.again, color: LangoColors.error),
    (label: 'Hard', rating: ReviewRating.hard, color: LangoColors.warning),
    (label: 'Good', rating: ReviewRating.good, color: LangoColors.success),
    (label: 'Easy', rating: ReviewRating.easy, color: LangoColors.primary),
  ];

  /// Below this per-button width the labels start to wrap mid-word.
  static const _minButtonWidth = 78.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perButton =
            (constraints.maxWidth - LangoSpace.xs * 3) / _options.length;
        final singleRow = perButton >= _minButtonWidth;

        if (singleRow) {
          return Row(
            children: [
              for (var i = 0; i < _options.length; i++) ...[
                Expanded(child: _button(_options[i])),
                if (i != _options.length - 1)
                  const SizedBox(width: LangoSpace.xs),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(children: [
              Expanded(child: _button(_options[0])),
              const SizedBox(width: LangoSpace.xs),
              Expanded(child: _button(_options[1])),
            ]),
            const SizedBox(height: LangoSpace.xs),
            Row(children: [
              Expanded(child: _button(_options[2])),
              const SizedBox(width: LangoSpace.xs),
              Expanded(child: _button(_options[3])),
            ]),
          ],
        );
      },
    );
  }

  Widget _button(({String label, ReviewRating rating, Color color}) o) {
    return Semantics(
      button: true,
      label: '${o.label} — rate your recall',
      child: FilledButton(
        onPressed: enabled ? () => onRate(o.rating) : null,
        style: FilledButton.styleFrom(
          backgroundColor: LangoColors.surfaceMuted,
          foregroundColor: o.color,
          disabledBackgroundColor: LangoColors.surfaceMuted,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: LangoSpace.xs),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: LangoRadius.mdAll),
        ),
        child: Text(
          o.label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: LangoType.label.copyWith(color: o.color),
        ),
      ),
    );
  }
}
