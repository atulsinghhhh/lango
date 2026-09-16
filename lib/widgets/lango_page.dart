import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Page container (REDESIGN.md §4, §29).
///
/// Applies the measured page gutter and caps content at a single readable
/// column so wide screens centre the phone layout rather than stretching it —
/// the reference is a single 390pt column and stays one on a tablet.
class LangoPage extends StatelessWidget {
  const LangoPage({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.actions,
    this.scrollable = true,
    this.padHorizontal = true,
    this.bottomBar,
  });

  final Widget child;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;

  /// When false the caller owns scrolling (e.g. a paged study flow).
  final bool scrollable;
  final bool padHorizontal;

  /// Bottom-anchored primary action, per the reference's single-CTA pattern.
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final gutter = padHorizontal ? LangoSpace.gutter : 0.0;

    Widget content = Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: child,
    );

    if (scrollable) {
      content = SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: LangoSpace.xxl),
        child: content,
      );
    }

    content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: LangoBreak.maxContentWidth),
        child: content,
      ),
    );

    return Scaffold(
      appBar: (title == null && leading == null && actions == null)
          ? null
          : AppBar(
              title: title == null ? null : Text(title!),
              leading: leading,
              actions: actions,
            ),
      body: SafeArea(child: content),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              minimum: EdgeInsets.fromLTRB(
                gutter,
                LangoSpace.sm,
                gutter,
                LangoSpace.md,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: LangoBreak.maxContentWidth),
                  child: bottomBar,
                ),
              ),
            ),
    );
  }
}

/// Vertical rhythm helpers, so screens stop writing raw `SizedBox(height: 17)`.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});

  const Gap.xs({super.key}) : size = LangoSpace.xs;
  const Gap.sm({super.key}) : size = LangoSpace.sm;
  const Gap.md({super.key}) : size = LangoSpace.md;
  const Gap.lg({super.key}) : size = LangoSpace.lg;
  const Gap.xl({super.key}) : size = LangoSpace.xl;
  const Gap.card({super.key}) : size = LangoSpace.cardGap;
  const Gap.xxl({super.key}) : size = LangoSpace.xxl;
  const Gap.xxs({super.key}) : size = LangoSpace.xxs;

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}
