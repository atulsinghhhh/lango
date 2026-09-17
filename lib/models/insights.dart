/// Weak-area analysis (US-100).
///
/// Everything here is derived from recorded activity — `exercise_attempts`,
/// `review_events`, `speaking_attempts`. A weak area is never asserted from a
/// single mistake: see [WeakArea.minimumAttempts].
library;

/// What kind of thing the learner is struggling with, so the app can point at
/// the right practice rather than a generic "study more".
enum WeakAreaKind {
  /// A group of words — by part of speech or content tag.
  vocabulary,

  /// A specific grammar pattern.
  grammar,

  /// A writing-system character.
  character,

  /// A whole skill: listening, speaking, typing.
  skill,
}

class WeakArea {
  const WeakArea({
    required this.label,
    required this.kind,
    required this.attempts,
    required this.correct,
    this.itemIds = const [],
  });

  /// Human-readable category, e.g. "Korean particles" or "Listening".
  final String label;
  final WeakAreaKind kind;

  /// How many graded attempts this is based on.
  final int attempts;
  final int correct;

  /// The specific items behind it, so practice can be scoped to them.
  final List<String> itemIds;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;
  int get incorrect => attempts - correct;

  /// Below this many attempts we do not claim to have found a weakness —
  /// two wrong answers is noise, not a pattern (CLAUDE.md: don't claim
  /// accuracy the system can't measure).
  static const minimumAttempts = 4;

  /// Above this accuracy the learner is not struggling.
  static const weakBelowAccuracy = 0.7;

  bool get isWeak =>
      attempts >= minimumAttempts && accuracy < weakBelowAccuracy;
}
