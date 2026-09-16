import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/lango_page.dart';

/// Auth shell (REDESIGN.md §4, §6).
///
/// The reference's first screen is a full-bleed violet→pink→white wash with a
/// large native wordmark. That hero is the product's front door, so both auth
/// screens sit on it, with the form in a white sheet floating on the wash.
/// This is the only place the large gradient is used (§5).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: langoHeroGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(LangoSpace.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Wordmark(),
                    const Gap.xxl(),
                    Container(
                      decoration: const BoxDecoration(
                        color: LangoPalette.white,
                        borderRadius: LangoRadius.xlAll,
                      ),
                      padding: const EdgeInsets.all(LangoSpace.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title, style: LangoType.h2),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(subtitle!, style: LangoType.bodyMuted),
                          ],
                          const Gap.xl(),
                          child,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learn',
          style: LangoType.h1.copyWith(color: LangoColors.primaryForeground),
        ),
        const SizedBox(height: 2),
        // Native-first: the two languages are the wordmark, in their own
        // scripts and their own faces (REDESIGN.md §12).
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '한국어',
              style: LangoType.native('ko',
                  size: 40, color: LangoColors.primaryDeep),
            ),
            Text(
              '  ·  ',
              style: LangoType.h2.copyWith(color: LangoColors.primaryDeep),
            ),
            Text(
              '日本語',
              style: LangoType.native('ja',
                  size: 40, color: LangoColors.primaryDeep),
            ),
          ],
        ),
      ],
    );
  }
}
