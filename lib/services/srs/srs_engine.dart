/// Spaced-repetition scheduling engine (SM-2 variant).
///
/// Pure and deterministic: identical input always produces identical output
/// (US-032). No I/O, no clock access — the caller supplies `reviewedAt`.
/// The algorithm is behind [SrsEngine] so it can evolve (FSRS, custom)
/// without touching persistence or UI code.
library;

/// Learner's self-reported / measured recall quality for one review.
enum ReviewRating { again, hard, good, easy }

/// Scheduling state of a single item. Storage-agnostic.
class SrsState {
  const SrsState({
    this.status = 'new',
    this.ease = 2.5,
    this.intervalMinutes = 0,
    this.repetitions = 0,
  });

  final String status; // new | learning | review | mastered
  final double ease;
  final int intervalMinutes;
  final int repetitions;

  @override
  bool operator ==(Object other) =>
      other is SrsState &&
      other.status == status &&
      other.ease == ease &&
      other.intervalMinutes == intervalMinutes &&
      other.repetitions == repetitions;

  @override
  int get hashCode => Object.hash(status, ease, intervalMinutes, repetitions);
}

class SrsResult {
  const SrsResult({required this.state, required this.nextReview});

  final SrsState state;
  final DateTime nextReview;
}

class SrsEngine {
  static const _minEase = 1.3;
  static const _maxEase = 3.0;
  static const _dayMinutes = 24 * 60;

  /// Interval (in days) at or beyond which an item counts as mastered.
  static const masteredThresholdDays = 21;

  /// Relearning step used after a failure.
  static const _againStepMinutes = 10;

  /// Compute the next scheduling state after one review.
  SrsResult review({
    required SrsState current,
    required ReviewRating rating,
    required DateTime reviewedAt,
  }) {
    final next = switch (rating) {
      ReviewRating.again => _fail(current),
      ReviewRating.hard => _pass(current, easeDelta: -0.15, growth: 1.2),
      ReviewRating.good => _pass(current, easeDelta: 0.0, growth: null),
      ReviewRating.easy => _pass(current, easeDelta: 0.15, growth: null,
          easyBonus: 1.3),
    };
    return SrsResult(
      state: next,
      nextReview: reviewedAt.add(Duration(minutes: next.intervalMinutes)),
    );
  }

  SrsState _fail(SrsState s) => SrsState(
        status: 'learning',
        ease: _clampEase(s.ease - 0.2),
        intervalMinutes: _againStepMinutes,
        repetitions: 0,
      );

  SrsState _pass(
    SrsState s, {
    required double easeDelta,
    required double? growth,
    double easyBonus = 1.0,
  }) {
    final ease = _clampEase(s.ease + easeDelta);
    final reps = s.repetitions + 1;

    int intervalMinutes;
    if (s.repetitions == 0) {
      intervalMinutes = 1 * _dayMinutes;
    } else if (s.repetitions == 1) {
      intervalMinutes = 6 * _dayMinutes;
    } else {
      final factor = growth ?? ease;
      intervalMinutes =
          (s.intervalMinutes * factor * easyBonus).round();
      // Growth must always move the schedule forward by at least a day.
      if (intervalMinutes < s.intervalMinutes + _dayMinutes) {
        intervalMinutes = s.intervalMinutes + _dayMinutes;
      }
    }

    final intervalDays = intervalMinutes / _dayMinutes;
    final status =
        intervalDays >= masteredThresholdDays ? 'mastered' : 'review';

    return SrsState(
      status: status,
      ease: ease,
      intervalMinutes: intervalMinutes,
      repetitions: reps,
    );
  }

  double _clampEase(double e) => e.clamp(_minEase, _maxEase);
}
