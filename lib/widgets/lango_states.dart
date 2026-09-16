import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'lango_page.dart';

/// Empty, loading and error states (REDESIGN.md §26, §27, §28).
///
/// The audit found every screen using a bare `CircularProgressIndicator`, most
/// with no empty state and no error state at all. These three widgets are the
/// only sanctioned way to render those conditions.

/// A designed empty state — never a blank area or a raw "No data".
class LangoEmpty extends StatelessWidget {
  const LangoEmpty({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LangoSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: LangoPalette.tintPink,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: LangoColors.primaryDeep),
            ),
            const Gap.lg(),
          ],
          Text(title, style: LangoType.h3, textAlign: TextAlign.center),
          if (message != null) ...[
            const Gap.xs(),
            Text(
              message!,
              style: LangoType.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const Gap.lg(),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// A user-readable error. Never surfaces stack traces, database errors or
/// infrastructure detail (REDESIGN.md §28) — the underlying exception is
/// deliberately not rendered.
class LangoError extends StatelessWidget {
  const LangoError({
    super.key,
    this.title = 'Something went wrong.',
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LangoSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: LangoType.h3, textAlign: TextAlign.center),
          const Gap.xs(),
          Text(message,
              style: LangoType.bodyMuted, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const Gap.lg(),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

/// A skeleton block. Shape-matched placeholders beat a spinner because the
/// layout does not jump when data lands (REDESIGN.md §27).
class LangoSkeleton extends StatefulWidget {
  const LangoSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = LangoRadius.sm,
  });

  /// A full card-shaped placeholder.
  const LangoSkeleton.card({super.key})
      : height = 132,
        width = double.infinity,
        radius = LangoRadius.xl;

  final double height;
  final double? width;
  final double radius;

  @override
  State<LangoSkeleton> createState() => _LangoSkeletonState();
}

class _LangoSkeletonState extends State<LangoSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    // Respect prefers-reduced-motion (REDESIGN.md §35, §36).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MediaQuery.disableAnimationsOf(context)) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.isAnimating ? _c.value : 0.5;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(
              LangoColors.surfaceMuted,
              LangoColors.borderSubtle,
              t,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// Convenience: a stack of card skeletons matching a list layout.
class LangoSkeletonList extends StatelessWidget {
  const LangoSkeletonList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          const LangoSkeleton.card(),
          if (i != count - 1) const Gap.card(),
        ],
      ],
    );
  }
}

/// Renders an [AsyncValue]-shaped triple consistently everywhere.
class LangoAsync<T> extends StatelessWidget {
  const LangoAsync({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.errorMessage = "We couldn't load this. Check your connection.",
    this.loading,
  });

  /// `AsyncValue<T>` from Riverpod, passed as its three cases to avoid a
  /// hard dependency on Riverpod inside the widget library.
  final ({T? data, Object? error, bool isLoading}) value;
  final Widget Function(T) data;
  final VoidCallback onRetry;
  final String errorMessage;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    if (value.error != null) {
      return LangoError(message: errorMessage, onRetry: onRetry);
    }
    final d = value.data;
    if (value.isLoading && d == null) {
      return loading ?? const LangoSkeletonList();
    }
    if (d == null) return loading ?? const LangoSkeletonList();
    return data(d);
  }
}
