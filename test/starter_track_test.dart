import 'package:flutter_test/flutter_test.dart';
import 'package:lango/models/language.dart';
import 'package:lango/services/learn/starter_track.dart';

void main() {
  const track = StarterTrack();

  /// Hangul-sized alphabet: one foundational script, forty characters.
  ScriptProgress hangul({int learned = 0, int total = 40}) =>
      ScriptProgress(script: 'hangul', learned: learned, total: total);

  ScriptProgress kana(String script, {int learned = 0, int total = 46}) =>
      ScriptProgress(script: script, learned: learned, total: total);

  /// Kanji: levelled, so it is not part of the foundation.
  ScriptProgress kanji({int learned = 0, int total = 80}) => ScriptProgress(
        script: 'kanji',
        learned: learned,
        total: total,
        isLevelled: true,
      );

  StarterSnapshot snapshot({
    TargetLanguage language = TargetLanguage.korean,
    ProficiencyLevel level = ProficiencyLevel.completeBeginner,
    List<ScriptProgress>? scripts,
    int vocabularyTracked = 0,
    int grammarTracked = 0,
    bool hasListened = false,
    bool hasTakenDictation = false,
    bool hasSpoken = false,
    bool hasMessagedTutor = false,
  }) =>
      StarterSnapshot(
        language: language,
        level: level,
        scripts: scripts ?? [hangul()],
        vocabularyTracked: vocabularyTracked,
        grammarTracked: grammarTracked,
        hasListened: hasListened,
        hasTakenDictation: hasTakenDictation,
        hasSpoken: hasSpoken,
        hasMessagedTutor: hasMessagedTutor,
      );

  /// A learner who has finished everything, used to test the tail of the path.
  StarterSnapshot finished({List<ScriptProgress>? scripts}) => snapshot(
        scripts: scripts ?? [hangul(learned: 40)],
        vocabularyTracked: StarterTrack.firstWordsTarget,
        grammarTracked: StarterTrack.firstGrammarTarget,
        hasListened: true,
        hasTakenDictation: true,
        hasSpoken: true,
        hasMessagedTutor: true,
      );

  group('StarterTrack shape', () {
    test('the alphabet comes first', () {
      final plan = track.plan(snapshot());
      expect(plan.steps.first.kind, StarterStepKind.script);
      expect(plan.steps.first.script, 'hangul');
    });

    test('every learning mode appears exactly once', () {
      final plan = track.plan(snapshot());
      final kinds = plan.steps.map((s) => s.kind).toList();
      expect(
        kinds,
        containsAll(<StarterStepKind>[
          StarterStepKind.script,
          StarterStepKind.vocabulary,
          StarterStepKind.listening,
          StarterStepKind.dictation,
          StarterStepKind.grammar,
          StarterStepKind.speaking,
          StarterStepKind.tutor,
        ]),
      );
      final nonScript = kinds.where((k) => k != StarterStepKind.script);
      expect(nonScript.toSet().length, nonScript.length,
          reason: 'no mode should be offered twice');
    });

    test('a language with two syllabaries gets a step for each, in order', () {
      final plan = track.plan(snapshot(
        language: TargetLanguage.japanese,
        scripts: [kana('hiragana'), kana('katakana'), kanji()],
      ));
      final scripts =
          plan.steps.where((s) => s.script != null).map((s) => s.script);
      expect(scripts, ['hiragana', 'katakana']);
    });

    test('a levelled script is not a foundation step', () {
      final plan = track.plan(snapshot(
        language: TargetLanguage.japanese,
        scripts: [kana('hiragana'), kanji()],
      ));
      expect(plan.steps.map((s) => s.script), isNot(contains('kanji')));
    });

    test('no foundational script means no path at all', () {
      final plan = track.plan(snapshot(scripts: [kanji()]));
      expect(plan.isEmpty, isTrue);
    });

    test('an empty catalog means no path rather than an invented one', () {
      final plan = track.plan(snapshot(scripts: const []));
      expect(plan.isEmpty, isTrue);
    });

    test('every step states what it is for', () {
      final plan = track.plan(snapshot());
      for (final step in plan.steps) {
        expect(step.purpose, isNotEmpty, reason: '${step.title} has no reason');
        expect(step.title, isNotEmpty);
        expect(step.route, startsWith('/'));
      }
    });
  });

  group('sequencing', () {
    test('a learner at zero is pointed at the first step and nothing else', () {
      final plan = track.plan(snapshot());
      expect(plan.steps.first.state, StarterStepState.current);
      expect(
        plan.steps.skip(1).every((s) => s.state == StarterStepState.locked),
        isTrue,
      );
    });

    test('exactly one step is current', () {
      final plan = track.plan(snapshot(scripts: [hangul(learned: 20)]));
      expect(plan.steps.where((s) => s.isCurrent).length, 1);
    });

    test('finishing the script moves the path on to words', () {
      final plan = track.plan(snapshot(scripts: [hangul(learned: 40)]));
      expect(plan.steps.first.isDone, isTrue);
      expect(plan.current?.kind, StarterStepKind.vocabulary);
    });

    test('work done out of order still counts as done', () {
      // Someone who recorded themselves on day one before learning the script.
      final plan = track.plan(snapshot(hasSpoken: true));
      final speaking =
          plan.steps.firstWhere((s) => s.kind == StarterStepKind.speaking);
      expect(speaking.isDone, isTrue);
      expect(plan.current?.kind, StarterStepKind.script,
          reason: 'the path still starts at the beginning');
    });

    test('a finished path has no current step', () {
      final plan = track.plan(finished());
      expect(plan.isComplete, isTrue);
      expect(plan.current, isNull);
      expect(plan.fraction, 1.0);
    });

    test('progress is the share of steps done', () {
      final plan = track.plan(snapshot(scripts: [hangul(learned: 40)]));
      expect(plan.doneCount, 1);
      expect(plan.fraction, closeTo(1 / plan.steps.length, 0.0001));
    });
  });

  group('the script threshold', () {
    test('most of the alphabet is enough to move on', () {
      final learned = (40 * StarterTrack.scriptReadyFraction).ceil();
      final plan = track.plan(snapshot(scripts: [hangul(learned: learned)]));
      expect(plan.steps.first.isDone, isTrue);
    });

    test('one short of the threshold is not', () {
      final learned = (40 * StarterTrack.scriptReadyFraction).ceil() - 1;
      final plan = track.plan(snapshot(scripts: [hangul(learned: learned)]));
      expect(plan.steps.first.isDone, isFalse);
    });

    test('the second syllabary waits for the first', () {
      final plan = track.plan(snapshot(
        language: TargetLanguage.japanese,
        scripts: [kana('hiragana'), kana('katakana')],
      ));
      expect(plan.steps[0].isCurrent, isTrue);
      expect(plan.steps[1].isLocked, isTrue);
    });
  });

  group('thresholds for the other steps', () {
    test('words count toward the first-words step', () {
      final plan = track.plan(snapshot(
        scripts: [hangul(learned: 40)],
        vocabularyTracked: StarterTrack.firstWordsTarget,
      ));
      final vocab =
          plan.steps.firstWhere((s) => s.kind == StarterStepKind.vocabulary);
      expect(vocab.isDone, isTrue);
    });

    test('one word short is not done', () {
      final plan = track.plan(snapshot(
        scripts: [hangul(learned: 40)],
        vocabularyTracked: StarterTrack.firstWordsTarget - 1,
      ));
      final vocab =
          plan.steps.firstWhere((s) => s.kind == StarterStepKind.vocabulary);
      expect(vocab.isDone, isFalse);
      expect(vocab.isCurrent, isTrue);
      expect(vocab.progress, closeTo(0.9, 0.0001));
    });

    test('listening, dictation, speaking and the tutor are yes or no', () {
      final plan = track.plan(snapshot(
        hasListened: true,
        hasTakenDictation: true,
        hasSpoken: true,
        hasMessagedTutor: true,
      ));
      for (final kind in [
        StarterStepKind.listening,
        StarterStepKind.dictation,
        StarterStepKind.speaking,
        StarterStepKind.tutor,
      ]) {
        expect(plan.steps.firstWhere((s) => s.kind == kind).isDone, isTrue);
      }
    });
  });

  group('hints', () {
    test('the current step says what would finish it', () {
      final plan = track.plan(snapshot(scripts: [hangul(learned: 10)]));
      expect(plan.current!.nextHint, contains('22'),
          reason: '80% of 40 is 32, and 32 - 10 = 22 still to start');
    });

    test('only the current step carries a hint', () {
      final plan = track.plan(snapshot());
      final withHints = plan.steps.where((s) => s.nextHint != null);
      expect(withHints.length, 1);
      expect(withHints.first.isCurrent, isTrue);
    });

    test('a hint for one remaining item reads in the singular', () {
      final learned = (40 * StarterTrack.scriptReadyFraction).ceil() - 1;
      final plan = track.plan(snapshot(scripts: [hangul(learned: learned)]));
      expect(plan.current!.nextHint, contains('1 more character'));
    });
  });

  group('audience', () {
    test('a complete beginner wants the path', () {
      expect(
        snapshot(level: ProficiencyLevel.completeBeginner).wantsGuidance,
        isTrue,
      );
    });

    test('a beginner wants it too', () {
      expect(
        snapshot(level: ProficiencyLevel.beginner).wantsGuidance,
        isTrue,
      );
    });

    test('an intermediate learner is never sent back to the alphabet', () {
      for (final level in [
        ProficiencyLevel.elementary,
        ProficiencyLevel.intermediate,
        ProficiencyLevel.advanced,
      ]) {
        expect(snapshot(level: level).wantsGuidance, isFalse,
            reason: '${level.code} should not be offered the starter path');
      }
    });
  });

  group('determinism', () {
    test('the same snapshot always produces the same path', () {
      final a = track.plan(snapshot(scripts: [hangul(learned: 12)]));
      final b = track.plan(snapshot(scripts: [hangul(learned: 12)]));
      expect(
        a.steps.map((s) => '${s.kind}:${s.state}'),
        b.steps.map((s) => '${s.kind}:${s.state}'),
      );
    });
  });
}
