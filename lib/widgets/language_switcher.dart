import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/language.dart';
import '../models/profile.dart';
import '../services/providers.dart';

/// Language switching (REDESIGN.md §12).
///
/// Korean and Japanese are first-class: each is shown by flag *and* by its own
/// endonym (한국어 / 日本語) in its own typeface, never as an English label
/// with a flag bolted on. Switching is one tap and immediately re-scopes every
/// area of the product through [activeLanguageProvider].
extension LanguageDisplay on TargetLanguage {
  /// The language's name in its own script.
  String get endonym => switch (this) {
        TargetLanguage.korean => '한국어',
        TargetLanguage.japanese => '日本語',
      };
}

/// Segmented switcher for learners studying more than one language.
class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key, required this.languages});

  final List<UserLanguage> languages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (languages.length < 2) return const SizedBox.shrink();
    final active = ref.watch(effectiveLanguageProvider);

    return Semantics(
      label: 'Study language',
      child: Row(
        children: [
          for (final ul in languages) ...[
            Expanded(
              child: _LanguagePill(
                language: ul.language,
                selected: ul.language == active,
                onTap: () => ref
                    .read(activeLanguageProvider.notifier)
                    .select(ul.language),
              ),
            ),
            if (ul != languages.last) const SizedBox(width: LangoSpace.sm),
          ],
        ],
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final TargetLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = language == TargetLanguage.korean
        ? LangoPalette.tintPink
        : LangoPalette.tintSky;

    return Semantics(
      selected: selected,
      button: true,
      label: '${language.label} (${language.endonym})',
      child: Material(
        color: Colors.transparent,
        borderRadius: LangoRadius.pillAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: LangoRadius.pillAll,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : LangoMotion.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: LangoSpace.md,
              vertical: LangoSpace.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? tint : LangoColors.surfaceMuted,
              borderRadius: LangoRadius.pillAll,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(language.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: LangoSpace.xs),
                Flexible(
                  child: Text(
                    language.endonym,
                    overflow: TextOverflow.ellipsis,
                    style: LangoType.native(
                      language.code,
                      size: 16,
                      weight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected
                          ? LangoColors.foreground
                          : LangoColors.foregroundMuted,
                    ),
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

/// Compact badge for headers and card corners.
class LanguageBadge extends StatelessWidget {
  const LanguageBadge({super.key, required this.language, this.showEndonym = true});

  final TargetLanguage language;
  final bool showEndonym;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(language.flag, style: const TextStyle(fontSize: 16)),
        if (showEndonym) ...[
          const SizedBox(width: LangoSpace.xs),
          Text(
            language.endonym,
            style: LangoType.native(language.code, size: 15),
          ),
        ],
      ],
    );
  }
}
