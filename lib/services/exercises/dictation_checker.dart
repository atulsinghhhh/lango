import '../speech/speech_comparison.dart';

/// Dictation grading (US-071).
///
/// Pure and deterministic, like [ExerciseGenerator] and `SrsEngine`: the
/// screen decides nothing about what counts as correct.
class DictationResult {
  const DictationResult({
    required this.correct,
    required this.comparison,
  });

  final bool correct;

  /// Token-level diff, so a near miss can be shown rather than just failed.
  final SpeechComparison comparison;

  /// True when the answer was wrong but recognisably close — the learner heard
  /// the sentence and slipped on part of it, rather than missing it entirely.
  bool get isNearMiss => !correct && comparison.matchRatio >= 0.5;
}

class DictationChecker {
  const DictationChecker._();

  /// Grade [input] against [expected].
  ///
  /// Punctuation, case and spacing never decide the outcome: the acceptance
  /// criteria are explicit that minor formatting differences must not fail an
  /// otherwise correct answer. Anything else — a wrong particle, a dropped
  /// syllable — does fail, because that is the thing being practised.
  static DictationResult check(String input, String expected) {
    final correct = SpeechComparison.equivalent(input, expected);
    return DictationResult(
      correct: correct,
      comparison: SpeechComparison.compare(expected, input),
    );
  }
}
