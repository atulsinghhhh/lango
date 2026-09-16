import 'package:flutter_test/flutter_test.dart';
import 'package:lango/services/srs/srs_engine.dart';

void main() {
  final engine = SrsEngine();
  final t0 = DateTime.utc(2026, 1, 1, 12, 0);

  SrsResult run(SrsState s, ReviewRating r, [DateTime? at]) =>
      engine.review(current: s, rating: r, reviewedAt: at ?? t0);

  group('SrsEngine', () {
    test('is deterministic for identical input', () {
      const state = SrsState(
          status: 'review', ease: 2.3, intervalMinutes: 6 * 1440, repetitions: 2);
      final a = run(state, ReviewRating.good);
      final b = run(state, ReviewRating.good);
      expect(a.state, equals(b.state));
      expect(a.nextReview, equals(b.nextReview));
    });

    test('first correct answer schedules 1 day out', () {
      final r = run(const SrsState(), ReviewRating.good);
      expect(r.state.intervalMinutes, 1440);
      expect(r.state.status, 'review');
      expect(r.state.repetitions, 1);
      expect(r.nextReview, t0.add(const Duration(days: 1)));
    });

    test('second correct answer schedules 6 days out', () {
      final first = run(const SrsState(), ReviewRating.good);
      final second = run(first.state, ReviewRating.good);
      expect(second.state.intervalMinutes, 6 * 1440);
    });

    test('third correct answer grows by ease factor', () {
      var s = const SrsState();
      s = run(s, ReviewRating.good).state;
      s = run(s, ReviewRating.good).state;
      final third = run(s, ReviewRating.good).state;
      expect(third.intervalMinutes, (6 * 1440 * 2.5).round());
    });

    test('incorrect answer resets to a 10-minute learning step', () {
      const state = SrsState(
          status: 'review',
          ease: 2.5,
          intervalMinutes: 10 * 1440,
          repetitions: 3);
      final r = run(state, ReviewRating.again);
      expect(r.state.status, 'learning');
      expect(r.state.intervalMinutes, 10);
      expect(r.state.repetitions, 0);
      expect(r.state.ease, 2.3); // decreased
      expect(r.nextReview, t0.add(const Duration(minutes: 10)));
    });

    test('incorrect answers increase review priority (sooner than correct)',
        () {
      const state = SrsState(
          status: 'review', ease: 2.5, intervalMinutes: 1440, repetitions: 1);
      final wrong = run(state, ReviewRating.again);
      final right = run(state, ReviewRating.good);
      expect(wrong.nextReview.isBefore(right.nextReview), isTrue);
    });

    test('easy grows faster than good, hard grows slower', () {
      const state = SrsState(
          status: 'review',
          ease: 2.5,
          intervalMinutes: 6 * 1440,
          repetitions: 2);
      final hard = run(state, ReviewRating.hard).state;
      final good = run(state, ReviewRating.good).state;
      final easy = run(state, ReviewRating.easy).state;
      expect(hard.intervalMinutes, lessThan(good.intervalMinutes));
      expect(good.intervalMinutes, lessThan(easy.intervalMinutes));
    });

    test('ease never drops below 1.3', () {
      var s = const SrsState(ease: 1.4);
      s = run(s, ReviewRating.again).state;
      s = run(s, ReviewRating.again).state;
      expect(s.ease, 1.3);
    });

    test('item becomes mastered once interval reaches 21 days', () {
      var s = const SrsState();
      var status = s.status;
      for (var i = 0; i < 10 && status != 'mastered'; i++) {
        s = run(s, ReviewRating.good).state;
        status = s.status;
      }
      expect(status, 'mastered');
      expect(s.intervalMinutes, greaterThanOrEqualTo(21 * 1440));
    });

    test('a pass always moves the schedule forward even at minimum ease', () {
      const state = SrsState(
          status: 'review',
          ease: 1.3,
          intervalMinutes: 6 * 1440,
          repetitions: 2);
      final r = run(state, ReviewRating.hard).state;
      expect(r.intervalMinutes, greaterThan(state.intervalMinutes));
    });
  });
}
