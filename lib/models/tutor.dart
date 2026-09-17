/// AI tutor models (US-090, US-091, US-092).
library;

import 'language.dart';

/// A correction of one learner turn (US-092).
///
/// Only present when the tutor found something meaningfully wrong. "Correct"
/// turns carry no correction rather than an empty one, so the UI never has to
/// render a correction that says nothing.
class TutorCorrection {
  const TutorCorrection({
    required this.original,
    required this.corrected,
    required this.explanation,
    this.example,
  });

  /// What the learner wrote.
  final String original;

  /// The corrected sentence.
  final String corrected;

  /// Why — kept to a sentence or two unless the learner asks for more.
  final String explanation;

  /// An optional extra sentence using the same pattern.
  final String? example;

  factory TutorCorrection.fromJson(Map<String, dynamic> json) =>
      TutorCorrection(
        original: json['original'] as String? ?? '',
        corrected: json['corrected'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
        example: json['example'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'original': original,
        'corrected': corrected,
        'explanation': explanation,
        if (example != null) 'example': example,
      };

  bool get isUsable =>
      corrected.trim().isNotEmpty && explanation.trim().isNotEmpty;
}

enum TutorRole { user, tutor }

class TutorMessage {
  const TutorMessage({
    required this.id,
    required this.role,
    required this.content,
    this.translation,
    this.correction,
    required this.createdAt,
  });

  final String id;
  final TutorRole role;

  /// Native-language text. Rendered with `LangoType.native`.
  final String content;

  /// English gloss of [content] for tutor turns, so a beginner is never stuck.
  final String? translation;

  /// Set on a tutor turn that corrects the learner's previous turn.
  final TutorCorrection? correction;

  final DateTime createdAt;

  factory TutorMessage.fromJson(Map<String, dynamic> json) => TutorMessage(
        id: json['id'] as String,
        role: json['role'] == 'user' ? TutorRole.user : TutorRole.tutor,
        content: json['content'] as String,
        translation: json['translation'] as String?,
        correction: json['correction'] == null
            ? null
            : TutorCorrection.fromJson(
                (json['correction'] as Map).cast<String, dynamic>()),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class TutorConversation {
  const TutorConversation({
    required this.id,
    required this.language,
    required this.level,
    this.scenario,
    this.title,
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final TargetLanguage language;

  /// The level the conversation was opened at, so an old conversation still
  /// reads correctly after the learner's level changes.
  final ProficiencyLevel level;
  final String? scenario;
  final String? title;
  final DateTime startedAt;
  final DateTime? endedAt;

  bool get isOpen => endedAt == null;

  factory TutorConversation.fromJson(Map<String, dynamic> json) =>
      TutorConversation(
        id: json['id'] as String,
        language: TargetLanguage.fromCode(json['language'] as String),
        level: ProficiencyLevel.fromCode(json['level'] as String),
        scenario: json['scenario'] as String?,
        title: json['title'] as String?,
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'] as String)
            : null,
      );
}

/// What the tutor backend is told about the learner (US-091).
///
/// Assembled from real recorded data — the learner's level, their chosen
/// goals, the words and patterns they have actually studied, and the mistakes
/// they have actually made. Nothing here is invented.
class TutorContext {
  const TutorContext({
    required this.language,
    required this.level,
    required this.goals,
    required this.vocabulary,
    required this.grammar,
    required this.recentMistakes,
    this.scenario,
  });

  final TargetLanguage language;
  final ProficiencyLevel level;
  final List<String> goals;

  /// Words the learner has been exposed to, so the tutor can stay inside them.
  final List<String> vocabulary;

  /// Grammar patterns the learner has studied.
  final List<String> grammar;

  /// Recent items answered incorrectly, as plain text.
  final List<String> recentMistakes;

  final String? scenario;

  Map<String, dynamic> toJson() => {
        'language': language.code,
        'language_name': language.label,
        'level': level.code,
        'level_label': level.label,
        'goals': goals,
        'vocabulary': vocabulary,
        'grammar': grammar,
        'recent_mistakes': recentMistakes,
        if (scenario != null) 'scenario': scenario,
      };
}

/// Why the tutor is unavailable, so the UI can say something specific rather
/// than "something went wrong".
enum TutorUnavailableReason {
  /// No tutor endpoint is deployed for this project.
  notConfigured,

  /// The endpoint exists but rejected the call (missing key, bad deploy).
  backendError,

  /// The device could not reach the endpoint.
  offline,
}

class TutorUnavailable implements Exception {
  const TutorUnavailable(this.reason);
  final TutorUnavailableReason reason;
}
