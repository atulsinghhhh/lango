import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Cards (REDESIGN.md §5, §9).
///
/// Flat by construction: no shadow, no elevation, no border — the reference
/// has none of the three (measured, REFERENCE_ANALYSIS.md §5). A card is
/// distinguished from the background purely by its pastel fill, which carries
/// the subtle top-to-bottom sheen measured on the reference's cards.
class LangoCard extends StatelessWidget {
  const LangoCard({
    super.key,
    required this.child,
    this.tint,
    this.onTap,
    this.padding = const EdgeInsets.all(LangoSpace.xl),
    this.semanticLabel,
  });

  /// Tinted variant — the default card style of the reference.
  const LangoCard.tinted({
    super.key,
    required this.child,
    required LangoTint this.tint,
    this.onTap,
    this.padding = const EdgeInsets.all(LangoSpace.xl),
    this.semanticLabel,
  });

  final Widget child;

  /// When null the card renders on the plain surface (used where a tint would
  /// add colour without adding meaning — see §6, "a component should not
  /// introduce a new color unless it has a clear semantic purpose").
  final LangoTint? tint;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      decoration: BoxDecoration(
        borderRadius: LangoRadius.xlAll,
        gradient: tint?.gradient,
        color: tint == null ? LangoColors.surfaceMuted : null,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) {
      return semanticLabel == null
          ? decorated
          : Semantics(label: semanticLabel, child: decorated);
    }

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: LangoRadius.xlAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: LangoRadius.xlAll,
          child: decorated,
        ),
      ),
    );
  }
}
