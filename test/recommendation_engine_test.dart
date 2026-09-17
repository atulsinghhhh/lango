import 'package:flutter_test/flutter_test.dart';
import 'package:lango/models/insights.dart';
import 'package:lango/models/language.dart';
import 'package:lango/services/recommend/recommendation_engine.dart';

void main() {
  const engine = RecommendationEngine();

  LearnerSnapshot snapshot({
    ProficiencyLevel level = ProficiencyLevel.intermediate,
    List<String> goals = const [],
    int dueReviews = 0,
    int untrackedVocabulary = 50,
    int charactersTracked = 20,
    int charactersAvailable = 40,
    int minutesStudiedToday = 0,
    int dailyGoalMinutes = 10,
    List<WeakArea> weakAreas = const [],
    Set<String> skillsPractisedThisWeek = const {},
  }) =>
      LearnerSnapshot(
        language: TargetLanguage.korean,
        level: level,
        goals: goals,
        dueReviews: dueReviews,
        untrackedVocabulary: untrackedVocabulary,
        charactersTracked: charactersTracked,
        charactersAvailable: charactersAvailable,
        minutesStudiedToday: minutesStudiedToday,
        dailyGoalMinutes: dailyGoalMinutes,
        weakAreas: weakAreas,
        skillsPractisedThisWeek: skillsPractisedThisWeek,
      );

  WeakArea area(String label, {int attempts = 10, int correct = 3}) =>
      WeakArea(
        label: label,
        kind: WeakAreaKind.grammar,
        attempts: attempts,
        correct: correct,
      );

  group('RecommendationEngine', () {
    test('is deterministic for identical input', () {
      final s = snapshot(dueReviews: 4);
      expect(engine.recommend(s).activity, engine.recommend(s).activity);
      expect(engine.recommend(s).title, engine.recommend(s).title);
    });

    test('always returns exactly one activity', () {
      // US-101: "The recommendation returns one primary next activity."
      expect(engine.recommend(snapshot()), isA<Recommendation>());
    });

    test('due reviews outrank everything else', () {
      final r = engine.recommend(snapshot(
        dueReviews: 12,
        weakAreas: [area('은/는')],
        level: ProficiencyLevel.completeBeginner,
        charactersTracked: 0,
        goals: const ['Conversation'],
      ));
      expect(r.activity, RecommendedActivity.review);
      expect(r.title, contains('12'));
    });

    test('a single due review is worded in the singular', () {
      final r = engine.recommend(snapshot(dueReviews: 1));
      expect(r.title, '1 review due');
    });

    test('a beginner who has not started the script learns it first', () {
      final r = engine.recommend(snapshot(
        level: ProficiencyLevel.completeBeginner,
        charactersTracked: 0,
        weakAreas: [area('은/는')],
      ));
      expect(r.activity, RecommendedActivity.writing);
    });

    test('an advanced learner is not sent back to the alphabet', () {
      final r = engine.recommend(snapshot(
        level: ProficiencyLevel.advanced,
        charactersTracked: 0,
      ));
      expect(r.activity, isNot(RecommendedActivity.writing));
    });

    test('a measured weakness beats the daily session', () {
      final r = engine.recommend(snapshot(weakAreas: [area('은/는')]));
      expect(r.activity, RecommendedActivity.targetedPractice);
      expect(r.title, 'Practise 은/는');
      expect(r.focus?.label, '은/는');
    });

    test('the reason quotes the evidence behind it', () {
      final r = engine
          .recommend(snapshot(weakAreas: [area('은/는', attempts: 10, correct: 3)]));
      expect(r.reason, contains('7 of 10'));
    });

    test('too few attempts is not a weakness', () {
      // Two wrong answers is noise, and claiming otherwise would be a metric
      // the system cannot support.
      final r = engine.recommend(snapshot(
        weakAreas: [area('은/는', attempts: 3, correct: 1)],
      ));
      expect(r.activity, isNot(RecommendedActivity.targetedPractice));
    });

    test('decent accuracy is not a weakness', () {
      final r = engine.recommend(snapshot(
        weakAreas: [area('은/는', attempts: 20, correct: 18)],
      ));
      expect(r.activity, isNot(RecommendedActivity.targetedPractice));
    });

    test('the worst area wins when several qualify', () {
      final r = engine.recommend(snapshot(weakAreas: [
        area('Listening', attempts: 10, correct: 6),
        area('은/는', attempts: 10, correct: 2),
        area('Verbs', attempts: 10, correct: 5),
      ]));
      expect(r.focus?.label, '은/는');
    });

    test('a tie on accuracy is broken by the larger sample', () {
      final r = engine.recommend(snapshot(weakAreas: [
        area('Verbs', attempts: 10, correct: 3),
        area('은/는', attempts: 40, correct: 12),
      ]));
      expect(r.focus?.label, '은/는');
      expect(r.focus?.attempts, 40);
    });

    test('a goal-relevant skill never practised is surfaced', () {
      final r = engine.recommend(snapshot(
        goals: const ['Conversation'],
        skillsPractisedThisWeek: const {'listening', 'vocabulary'},
      ));
      expect(r.activity, RecommendedActivity.speaking);
    });

    test('a skill already practised is not surfaced again', () {
      final r = engine.recommend(snapshot(
        goals: const ['Conversation'],
        skillsPractisedThisWeek: const {'speaking', 'listening'},
      ));
      expect(r.activity, isNot(RecommendedActivity.speaking));
      expect(r.activity, isNot(RecommendedActivity.listening));
    });

    test('goals the learner did not choose pull nothing forward', () {
      // "Reading" implies grammar, not speaking.
      final r = engine.recommend(snapshot(
        goals: const ['Reading'],
        skillsPractisedThisWeek: const {},
      ));
      expect(r.activity, RecommendedActivity.grammar);
    });

    test('with the goal still open a mixed session is suggested', () {
      final r = engine.recommend(
          snapshot(minutesStudiedToday: 2, dailyGoalMinutes: 20));
      expect(r.activity, RecommendedActivity.session);
      expect(r.estimatedMinutes, 18);
    });

    test('with almost no time left a shorter activity is suggested', () {
      // US-101 lists available study time as an input; a 20-minute session
      // does not fit into the two minutes left.
      final r = engine.recommend(
          snapshot(minutesStudiedToday: 8, dailyGoalMinutes: 10));
      expect(r.activity, RecommendedActivity.newVocabulary);
      expect(r.estimatedMinutes, 2);
    });

    test('once the goal is met the suggestion is new material', () {
      final r = engine.recommend(
          snapshot(minutesStudiedToday: 30, dailyGoalMinutes: 10));
      expect(r.activity, RecommendedActivity.newVocabulary);
    });

    test('with the whole catalog tracked it falls back to grammar', () {
      final r = engine.recommend(snapshot(
        minutesStudiedToday: 30,
        untrackedVocabulary: 0,
      ));
      expect(r.activity, RecommendedActivity.grammar);
    });

    test('every recommendation carries a reason', () {
      for (final s in [
        snapshot(dueReviews: 3),
        snapshot(level: ProficiencyLevel.beginner, charactersTracked: 0),
        snapshot(weakAreas: [area('은/는')]),
        snapshot(goals: const ['Conversation']),
        snapshot(minutesStudiedToday: 2, dailyGoalMinutes: 20),
        snapshot(minutesStudiedToday: 30),
        snapshot(minutesStudiedToday: 30, untrackedVocabulary: 0),
      ]) {
        expect(engine.recommend(s).reason, isNotEmpty);
      }
    });
  });

  group('LearnerSnapshot', () {
    test('minutes remaining never goes negative', () {
      expect(
          snapshot(minutesStudiedToday: 99, dailyGoalMinutes: 10)
              .minutesRemainingToday,
          0);
    });

    test('a language with no character set never demands the script', () {
      expect(
          snapshot(
            level: ProficiencyLevel.completeBeginner,
            charactersTracked: 0,
            charactersAvailable: 0,
          ).needsWritingSystem,
          isFalse);
    });
  });
}
