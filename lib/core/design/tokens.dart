/// Design tokens — the single source of truth for Lango's visual language
/// (REDESIGN.md §5, §32).
///
/// Every value here is measured from the reference image; see
/// REFERENCE_ANALYSIS.md for the measurement and the pixel evidence. Widgets
/// must read from these tokens (or from the [ThemeData] built on top of them)
/// and never hardcode a colour, radius, or spacing value.
library;

import 'package:flutter/widgets.dart';

/// Raw palette sampled from the reference. Prefer [LangoColors] semantic
/// names in UI code — these are the underlying swatches.
abstract final class LangoPalette {
  /// "start learning!" CTA fill.
  static const violet = Color(0xFF7213A8);

  /// Darkest ink of the 한국어 display wordmark.
  static const violetDeep = Color(0xFF580C8F);

  /// Poster background field.
  static const pink = Color(0xFFF4B2EB);

  // Hero gradient, sampled top → bottom down the left edge of screen 1.
  static const gradientTop = Color(0xFFBA82D8);
  static const gradientUpperMid = Color(0xFFCDA1E7);
  static const gradientLowerMid = Color(0xFFF0CFF1);
  static const gradientBottom = Color(0xFFFDFDFF);

  // Pastel category tints. Each card renders as a subtle vertical gradient
  // from `...Top` to the base colour — measured, not invented.
  static const tintPink = Color(0xFFF9DAF9);
  static const tintPinkTop = Color(0xFFFAEBFA);
  static const tintCyan = Color(0xFFBFF5FD);
  static const tintCyanTop = Color(0xFFD6F9FE);
  static const tintAmber = Color(0xFFFAE6AA);
  static const tintAmberTop = Color(0xFFFCF0C9);
  static const tintSky = Color(0xFFD9F1FE);
  static const tintSkyTop = Color(0xFFE8F7FE);

  static const white = Color(0xFFFEFEFE);
  static const ink = Color(0xFF131313);
  static const inkSecondary = Color(0xFF272727);

  /// Pinned at 5.28:1 on white. The reference's caption grey is lighter but
  /// fails WCAG AA at body size — the minimum deviation per REDESIGN.md §41.
  static const inkMuted = Color(0xFF6B6B6B);

  // Status. Kept desaturated to sit inside the pastel system instead of
  // shouting over it; all verified ≥4.5:1 on [white].
  static const success = Color(0xFF1B7A4B);
  static const warning = Color(0xFF9A6206);
  static const error = Color(0xFFB3261E);
}

/// Semantic colour roles (REDESIGN.md §6). UI code uses these names.
abstract final class LangoColors {
  static const background = LangoPalette.white;
  static const surface = LangoPalette.white;
  static const surfaceMuted = Color(0xFFF6F4F8);

  static const foreground = LangoPalette.ink;
  static const foregroundSecondary = LangoPalette.inkSecondary;
  static const foregroundMuted = LangoPalette.inkMuted;

  static const primary = LangoPalette.violet;
  static const primaryForeground = LangoPalette.white;
  static const primaryDeep = LangoPalette.violetDeep;

  static const accent = LangoPalette.pink;
  static const accentForeground = LangoPalette.ink;

  /// The reference draws no borders. These exist only for focus rings and
  /// input affordances, where accessibility requires a visible edge.
  static const border = Color(0xFFE4DEE9);
  static const borderSubtle = Color(0xFFF0EBF3);

  static const success = LangoPalette.success;
  static const warning = LangoPalette.warning;
  static const error = LangoPalette.error;

  /// Ordered tint ramp used to colour-code learning categories and cards.
  static const tints = <LangoTint>[
    LangoTint(base: LangoPalette.tintPink, top: LangoPalette.tintPinkTop),
    LangoTint(base: LangoPalette.tintCyan, top: LangoPalette.tintCyanTop),
    LangoTint(base: LangoPalette.tintAmber, top: LangoPalette.tintAmberTop),
    LangoTint(base: LangoPalette.tintSky, top: LangoPalette.tintSkyTop),
  ];

  /// Stable tint for a given key, so the same word or skill always reads the
  /// same colour across screens.
  static LangoTint tintFor(Object key) =>
      tints[key.hashCode.abs() % tints.length];
}

/// A pastel card fill: a subtle top-to-bottom gradient, never a flat block.
@immutable
class LangoTint {
  const LangoTint({required this.base, required this.top});

  final Color base;
  final Color top;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, base],
      );
}

/// The one large gradient in the system — hero / onboarding surfaces only.
const langoHeroGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    LangoPalette.gradientTop,
    LangoPalette.gradientUpperMid,
    LangoPalette.gradientLowerMid,
    LangoPalette.gradientBottom,
  ],
  stops: [0.0, 0.38, 0.75, 1.0],
);

/// Spacing scale (REDESIGN.md §8). The reference measures a 28 page gutter
/// and a 32 card gap.
abstract final class LangoSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;

  /// Page gutter — measured at ~28 in the reference.
  static const gutter = 28.0;

  /// Gap between stacked cards — measured at ~32.
  static const cardGap = 32.0;

  static const xxl = 40.0;
  static const xxxl = 48.0;
  static const huge = 64.0;
  static const giant = 80.0;
}

/// Corner geometry (REDESIGN.md §9). Cards are measurably twice as round as
/// buttons in the reference — 27pt vs 13pt.
abstract final class LangoRadius {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Motion (REDESIGN.md §35). Subtle and short; always check
/// [MediaQuery.disableAnimationsOf] before animating.
abstract final class LangoMotion {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);

  static const easing = Curves.easeOutCubic;
  static const emphasized = Curves.easeOutBack;
}

/// Breakpoints (REDESIGN.md §29). Mobile-first: the phone layout is the
/// default and these widen it.
abstract final class LangoBreak {
  static const compact = 480.0;
  static const medium = 768.0;
  static const expanded = 1024.0;

  /// Content never grows unbounded — the reference is a single 390pt column.
  static const maxContentWidth = 560.0;

  static bool isCompact(double w) => w < compact;
  static bool isMedium(double w) => w >= compact && w < expanded;
  static bool isExpanded(double w) => w >= expanded;
}
