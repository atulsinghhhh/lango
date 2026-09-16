/// Typography (REDESIGN.md §7). Sizes are derived from glyph ink-heights
/// measured in the reference — see REFERENCE_ANALYSIS.md §2.
library;

import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Font families. Latin UI text uses the rounded geometric sans; Hangul and
/// Kana fall back to the bundled Noto families so no glyph ever renders as a
/// missing box, regardless of platform.
abstract final class LangoFonts {
  static const latin = 'Nunito';
  static const korean = 'NotoSansKR';
  static const japanese = 'NotoSansJP';

  /// Default stack for UI chrome and English copy. Korean is listed before
  /// Japanese so shared CJK punctuation resolves consistently.
  static const uiFallback = <String>[korean, japanese];

  /// Stack for Korean content — Hangul first, so Hanja render in Korean
  /// style rather than being borrowed from the Japanese face.
  static const koreanFallback = <String>[japanese, latin];

  /// Stack for Japanese content — Kana and Kanji resolve from the Japanese
  /// face first.
  static const japaneseFallback = <String>[korean, latin];

  /// Resolve the right family for a piece of *native* content.
  ///
  /// [languageCode] is the `languages.code` value ('ko', 'ja', …). Unknown
  /// codes fall back to the UI stack, which still covers both scripts.
  static ({String family, List<String> fallback}) forLanguage(
      String? languageCode) {
    switch (languageCode) {
      case 'ko':
        return (family: korean, fallback: koreanFallback);
      case 'ja':
        return (family: japanese, fallback: japaneseFallback);
      default:
        return (family: latin, fallback: uiFallback);
    }
  }
}

/// The type scale. Names describe role, not size.
abstract final class LangoType {
  static const _f = LangoFonts.latin;
  static const _fb = LangoFonts.uiFallback;

  /// 64 — the hero native word on a study screen. The largest thing on any
  /// surface, per the reference's native-first hierarchy.
  static const display = TextStyle(
    fontFamily: _f,
    fontFamilyFallback: _fb,
    fontSize: 64,
    height: 1.12,
    fontWeight: FontWeight.w700,
    color: LangoColors.foreground,
  );

  /// 28 — screen-level wordmark / page title.
  static const h1 = TextStyle(
    fontFamily: _f,
    fontFamilyFallback: _fb,
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: LangoColors.foreground,
  );

  /// 24 — greeting, primary section heading.
  static const h2 = TextStyle(
    fontFamily: _f,
    fontFamilyFallback: _fb,
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: LangoColors.foreground,
  );

  /// 22 — sub-section heading, and the native word inside a card.
  static const h3 = TextStyle(
    fontFamily: _f,
    fontFamilyFallback: _fb,
    fontSize: 22,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: LangoColors.foreground,
  );

  /// 16 — default reading size.
  static const body = TextStyle(
    fontFamily: _f,
    fontFamilyFallback: _fb,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: LangoColors.foreground,
  );

  static const bodyMuted = TextStyle(
    fontFamily: _f,
    fontFamilyFallback: _fb,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: LangoColors.foregroundMuted,
  );

  /// 16/600 — button labels.
  static const label = TextStyle(
    fontFamily: _f,
    fontFamilyFallback: _fb,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: LangoColors.foreground,
  );

  /// 13, uppercase, tracked — the English gloss beneath a native word.
  /// Letter-spacing measured at ~0.08em in the reference.
  static const caption = TextStyle(
    fontFamily: _f,
    fontFamilyFallback: _fb,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 13 * 0.08,
    color: LangoColors.foregroundMuted,
  );

  /// 10, uppercase, tracked — bottom navigation labels.
  static const navLabel = TextStyle(
    fontFamily: _f,
    fontFamilyFallback: _fb,
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 10 * 0.08,
  );

  /// Native-language content. Always call this rather than using [display] or
  /// [h3] directly on Korean/Japanese text, so the correct face is selected.
  ///
  /// The native word is deliberately *not* styled as secondary metadata
  /// (REDESIGN.md §7).
  static TextStyle native(
    String? languageCode, {
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color color = LangoColors.foreground,
    double height = 1.3,
  }) {
    final f = LangoFonts.forLanguage(languageCode);
    return TextStyle(
      fontFamily: f.family,
      fontFamilyFallback: f.fallback,
      fontSize: size,
      height: height,
      fontWeight: weight,
      color: color,
    );
  }

  /// Hero-sized native content for one-task-at-a-time study screens.
  static TextStyle nativeDisplay(String? languageCode,
          {Color color = LangoColors.foreground}) =>
      native(languageCode, size: 64, height: 1.15, color: color);
}
